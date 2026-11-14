import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/auto_fetch.dart';
import '../core/background_fetch.dart';
import '../core/errors.dart';
import '../core/git_service.dart';
import '../core/notifications.dart';
import '../src/rust/error.dart';

/// Status of one repository on the dashboard.
class RepoView {
  const RepoView({
    required this.entry,
    this.status,
    this.error,
    this.fetchError,
  });

  final RepoEntry entry;
  final RepoStatus? status;

  /// Set when the status could not be read (folder moved, deleted, ...).
  final String? error;

  /// Last background-fetch failure, shown as a small warning.
  final String? fetchError;

  int get changes => status?.files.length ?? 0;
}

/// Owns the repository list, settings and per-repo status for the whole app.
class AppController extends ChangeNotifier {
  AppController(
    this.git, {
    this.notifier = const SilentNotifier(),
    this.background = const NoBackgroundFetch(),
    this.tick = const Duration(minutes: 1),
    this.onAuthRejected,
  });

  /// Called when a remote turns the sign-in down, so the GitHub account can
  /// be re-checked (a revoked token then signs out and asks to sign in).
  final Future<void> Function()? onAuthRejected;

  final GitService git;
  final FetchNotifier notifier;
  final BackgroundFetch background;

  /// How often the app checks whether a scheduled fetch is due.
  final Duration tick;

  Registry? _registry;
  final Map<String, RepoStatus> _status = {};
  final Map<String, String> _errors = {};
  final Map<String, String> _fetchErrors = {};
  final Set<String> _busy = {};
  Timer? _autoFetch;
  bool _fetchingAll = false;
  Future<void>? _autoRun;

  bool get loaded => _registry != null;
  AppSettings get settings => _registry!.settings;
  bool get fetchingAll => _fetchingAll;

  List<RepoView> get repos => [
    for (final e in _registry?.repos ?? const <RepoEntry>[])
      RepoView(
        entry: e,
        status: _status[e.path],
        error: _errors[e.path],
        fetchError: _fetchErrors[e.path],
      ),
  ];

  RepoEntry? entryFor(String path) {
    for (final e in _registry?.repos ?? const <RepoEntry>[]) {
      if (e.path == path) return e;
    }
    return null;
  }

  RepoStatus? statusFor(String path) => _status[path];
  bool isBusy(String path) => _busy.contains(path);

  PullStrategy pullStrategyFor(String path) =>
      entryFor(path)?.pullStrategy ?? settings.pullStrategy;

  /// Who to commit as in [path]; null leaves it to Git's own config.
  Identity? identityFor(String path) {
    final ids = settings.identities;
    if (ids.isEmpty) return null;
    final wanted = entryFor(path)?.identityEmail;
    if (wanted != null) {
      for (final id in ids) {
        if (id.email.toLowerCase() == wanted.toLowerCase()) return id;
      }
    }
    return ids[settings.defaultIdentity.clamp(0, ids.length - 1)];
  }

  /// Adds [id] (or updates the one with the same email) and, when
  /// [makeDefault], uses it from now on.
  Future<void> saveIdentity(Identity id, {bool makeDefault = false}) async {
    final ids = [...settings.identities];
    final at = ids.indexWhere(
      (i) => i.email.toLowerCase() == id.email.trim().toLowerCase(),
    );
    if (at >= 0) {
      ids[at] = id;
    } else {
      ids.add(id);
    }
    final index = at >= 0 ? at : ids.length - 1;
    await updateSettings(
      settings.copyWith(
        identities: ids,
        defaultIdentity: makeDefault || ids.length == 1
            ? index
            : settings.defaultIdentity,
      ),
    );
  }

  bool pushAfterCommitFor(String path) =>
      entryFor(path)?.pushAfterCommit ?? settings.pushAfterCommit;

  Future<void> init() async {
    _registry = await git.loadRegistry();
    notifyListeners();
    await refreshAll();
    _startAutoFetch();
    await background.sync(enabled: anyAutoFetch);
  }

  /// Whether any repository has automatic fetch turned on.
  bool get anyAutoFetch => (_registry?.repos ?? const <RepoEntry>[]).any(
    (r) => r.fetchSchedule.enabled,
  );

  @override
  void dispose() {
    _autoFetch?.cancel();
    super.dispose();
  }

  // ---- repository list -------------------------------------------------

  Future<AddReport> addRepos(List<String> paths) async {
    final report = await git.addRepos(paths);
    _registry = report.registry;
    notifyListeners();
    await Future.wait(report.added.map(refreshStatus));
    return report;
  }

  Future<List<String>> scan(String root) =>
      git.scanForRepos(root, settings.scanDepth);

  Future<void> removeRepo(String path) async {
    _registry = await git.removeRepo(path);
    _status.remove(path);
    _errors.remove(path);
    _fetchErrors.remove(path);
    notifyListeners();
  }

  Future<void> updateRepo(RepoEntry entry) async {
    _registry = await git.updateRepo(entry);
    notifyListeners();
    await background.sync(enabled: anyAutoFetch);
    // A newly enabled schedule is due right away.
    if (entry.fetchSchedule.enabled) unawaited(runAutoFetch());
  }

  Future<void> updateSettings(AppSettings next) async {
    _registry = await git.updateSettings(next);
    notifyListeners();
  }

  // ---- status ------------------------------------------------------------

  Future<void> refreshAll() async {
    final paths = [
      for (final r in _registry?.repos ?? const <RepoEntry>[]) r.path,
    ];
    await Future.wait(paths.map(refreshStatus));
  }

  Future<void> refreshStatus(String path) async {
    try {
      _status[path] = await git.status(path);
      _errors.remove(path);
    } catch (e) {
      _status.remove(path);
      _errors[path] = describeError(e);
    }
    notifyListeners();
  }

  // ---- remote operations -------------------------------------------------

  void _startAutoFetch() {
    _autoFetch?.cancel();
    _autoFetch = Timer.periodic(tick, (_) => runAutoFetch());
    unawaited(runAutoFetch());
  }

  /// Fetches the repositories whose schedule is due and notifies about new
  /// commits. Runs every [tick] while the app is open.
  Future<void> runAutoFetch({DateTime? now}) {
    final running = _autoRun;
    if (running != null) return running;
    if (!anyAutoFetch) return Future.value();
    return _autoRun = _autoFetchOnce(now).whenComplete(() => _autoRun = null);
  }

  Future<void> _autoFetchOnce(DateTime? now) async {
    try {
      final results = await runDueFetches(git, now: now, skip: {..._busy});
      if (results.isEmpty) return;
      for (final r in results) {
        if (r.error == null) {
          _fetchErrors.remove(r.path);
        } else {
          _fetchErrors[r.path] = describeError(r.error!);
        }
      }
      _registry = await git.loadRegistry();
      await Future.wait(results.map((r) => refreshStatus(r.path)));
      await notifier.newCommits([
        for (final r in results)
          if (r.newCommits != null) r.newCommits!,
      ]);
    } catch (_) {
      // Try again on the next tick.
    }
  }

  /// Fetches every repository now. Failures are recorded per repository
  /// instead of interrupting the rest.
  Future<void> fetchAll() async {
    if (_fetchingAll) return;
    _fetchingAll = true;
    notifyListeners();
    try {
      for (final e in _registry?.repos ?? const <RepoEntry>[]) {
        if (_busy.contains(e.path)) continue;
        await _fetchOne(e.path);
      }
    } finally {
      _fetchingAll = false;
      notifyListeners();
    }
  }

  Future<void> _fetchOne(String path) async {
    try {
      await git.fetch(path);
      _fetchErrors.remove(path);
    } catch (e) {
      _fetchErrors[path] = describeError(e);
      if (e is CoreError_Auth) await onAuthRejected?.call();
    }
    await refreshStatus(path);
  }

  /// Runs [op] with the repository marked busy, then refreshes its status.
  /// Errors are rethrown for the caller to show.
  Future<T> run<T>(String path, Future<T> Function() op) async {
    _busy.add(path);
    notifyListeners();
    try {
      return await op();
    } on CoreError_Auth {
      await onAuthRejected?.call();
      rethrow;
    } finally {
      _busy.remove(path);
      await refreshStatus(path);
    }
  }

  Future<FetchResult> fetch(String path) => run(path, () async {
    final r = await git.fetch(path);
    _fetchErrors.remove(path);
    return r;
  });

  Future<PullResult> pull(String path, {PullStrategy? strategy}) => run(
    path,
    () => git.pull(
      path,
      strategy ?? pullStrategyFor(path),
      identity: identityFor(path),
    ),
  );

  Future<PushResult> push(String path) => run(path, () => git.push(path));
}
