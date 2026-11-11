import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/errors.dart';
import '../core/git_service.dart';

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
  AppController(this.git);

  final GitService git;

  Registry? _registry;
  final Map<String, RepoStatus> _status = {};
  final Map<String, String> _errors = {};
  final Map<String, String> _fetchErrors = {};
  final Set<String> _busy = {};
  Timer? _autoFetch;
  bool _fetchingAll = false;

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

  bool pushAfterCommitFor(String path) =>
      entryFor(path)?.pushAfterCommit ?? settings.pushAfterCommit;

  Future<void> init() async {
    _registry = await git.loadRegistry();
    notifyListeners();
    _scheduleAutoFetch();
    await refreshAll();
  }

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
  }

  Future<void> updateSettings(AppSettings next) async {
    final intervalChanged = next.autoFetchMinutes != settings.autoFetchMinutes;
    _registry = await git.updateSettings(next);
    if (intervalChanged) _scheduleAutoFetch();
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

  void _scheduleAutoFetch() {
    _autoFetch?.cancel();
    final minutes = _registry?.settings.autoFetchMinutes ?? 0;
    if (minutes <= 0) return;
    _autoFetch = Timer.periodic(
      Duration(minutes: minutes),
      (_) => fetchAll(auto: true),
    );
  }

  /// Fetches every repository (only those with auto fetch on when [auto]).
  /// Failures are recorded per repository instead of interrupting the rest.
  Future<void> fetchAll({bool auto = false}) async {
    if (_fetchingAll) return;
    _fetchingAll = true;
    notifyListeners();
    try {
      for (final e in _registry?.repos ?? const <RepoEntry>[]) {
        if (auto && !e.autoFetch) continue;
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

  Future<PullResult> pull(String path, {PullStrategy? strategy}) =>
      run(path, () => git.pull(path, strategy ?? pullStrategyFor(path)));

  Future<PushResult> push(String path) => run(path, () => git.push(path));
}
