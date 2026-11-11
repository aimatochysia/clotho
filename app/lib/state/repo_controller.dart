import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/errors.dart';
import '../core/git_service.dart';
import 'app_controller.dart';

/// Which side of a file's changes is selected in the diff viewer.
class FileSelection {
  const FileSelection(this.path, {required this.staged});
  final String path;
  final bool staged;

  @override
  bool operator ==(Object other) =>
      other is FileSelection && other.path == path && other.staged == staged;
  @override
  int get hashCode => Object.hash(path, staged);
}

/// Result of a commit, including the optional automatic push.
class CommitOutcome {
  const CommitOutcome(this.commit, {this.push, this.pushError});
  final CommitResult commit;
  final PushResult? push;
  final String? pushError;
}

/// State for one open repository: changes, diff, branches and history.
class RepoController extends ChangeNotifier {
  RepoController({required this.app, required this.path});

  final AppController app;
  final String path;
  GitService get git => app.git;

  StreamSubscription<void>? _watch;
  bool _disposed = false;

  FileSelection? selection;
  FileDiff? diff;
  String? diffError;
  bool loadingDiff = false;

  List<BranchInfo>? branches;
  String? branchesError;

  final List<CommitInfo> history = [];
  bool historyDone = false;
  bool loadingHistory = false;
  bool allBranches = false;
  String? historyError;

  bool stageAllOnCommit = false;
  bool amend = false;

  RepoStatus? get status => app.statusFor(path);
  bool get busy => app.isBusy(path);
  bool get pushAfterCommit => app.pushAfterCommitFor(path);

  /// The no-diff check behind the Commit button: there must be something
  /// staged, or something to stage when "commit all" is on, and no conflicts.
  bool get canCommit {
    final s = status;
    if (s == null || s.conflictedCount > 0) return false;
    if (amend) return true;
    return s.stagedCount > 0 || (stageAllOnCommit && s.files.isNotEmpty);
  }

  Future<void> open() async {
    app.addListener(_onAppChanged);
    await app.refreshStatus(path);
    try {
      _watch = git.watch(path).listen((_) => refresh());
    } catch (_) {
      // Watching is a convenience; status still refreshes after each action.
    }
    await Future.wait([loadBranches(), loadHistory(reset: true)]);
  }

  void _onAppChanged() => _notify();

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    app.removeListener(_onAppChanged);
    _watch?.cancel();
    git.unwatch(path);
    super.dispose();
  }

  /// Re-reads status, the selected diff and branches after a change.
  Future<void> refresh() async {
    await app.refreshStatus(path);
    final sel = selection;
    if (sel != null) {
      final still = status?.files.any(
        (f) =>
            f.path == sel.path &&
            (sel.staged ? f.staged != null : f.unstaged != null),
      );
      if (still == true) {
        await _loadDiff(sel);
      } else {
        selection = null;
        diff = null;
      }
    }
    await loadBranches();
    _notify();
  }

  // ---- changes -------------------------------------------------------------

  Future<void> select(FileSelection sel) async {
    selection = sel;
    await _loadDiff(sel);
  }

  Future<void> _loadDiff(FileSelection sel) async {
    loadingDiff = true;
    diffError = null;
    _notify();
    try {
      diff = await git.diffFile(path, sel.path, staged: sel.staged);
    } catch (e) {
      diff = null;
      diffError = describeError(e);
    }
    loadingDiff = false;
    _notify();
  }

  Future<void> stage(List<String> files) async {
    await git.stage(path, files);
    await refresh();
  }

  Future<void> stageAll() async {
    await git.stageAll(path);
    await refresh();
  }

  Future<void> unstage(List<String> files) async {
    await git.unstage(path, files);
    await refresh();
  }

  Future<void> discard(List<String> files) async {
    await git.discard(path, files);
    await refresh();
  }

  void setStageAllOnCommit(bool v) {
    stageAllOnCommit = v;
    _notify();
  }

  void setAmend(bool v) {
    amend = v;
    _notify();
  }

  /// Commits, then pushes when the push-after-commit setting is on. A failed
  /// push does not undo the commit; it is reported in [CommitOutcome.pushError].
  Future<CommitOutcome> commit(String message) async {
    final result = await app.run(
      path,
      () => git.commit(path, message, stageAll: stageAllOnCommit, amend: amend),
    );
    amend = false;
    PushResult? pushed;
    String? pushError;
    if (pushAfterCommit) {
      try {
        pushed = await app.push(path);
      } catch (e) {
        pushError = describeError(e);
      }
    }
    await refresh();
    await loadHistory(reset: true);
    return CommitOutcome(result, push: pushed, pushError: pushError);
  }

  // ---- branches -------------------------------------------------------------

  Future<void> loadBranches() async {
    try {
      branches = await git.branches(path);
      branchesError = null;
    } catch (e) {
      branchesError = describeError(e);
    }
    _notify();
  }

  Future<void> checkout(String name) async {
    await app.run(path, () => git.checkout(path, name));
    await refresh();
    await loadHistory(reset: true);
  }

  Future<void> createBranch(
    String name, {
    String? from,
    bool checkout = true,
  }) async {
    await app.run(
      path,
      () => git.createBranch(path, name, startPoint: from, checkout: checkout),
    );
    await refresh();
    if (checkout) await loadHistory(reset: true);
  }

  Future<void> renameBranch(String oldName, String newName) async {
    await git.renameBranch(path, oldName, newName);
    await loadBranches();
  }

  Future<void> deleteBranch(String name, {bool force = false}) async {
    await git.deleteBranch(path, name, force: force);
    await loadBranches();
  }

  // ---- remote ---------------------------------------------------------------

  Future<FetchResult> fetch() async {
    final r = await app.fetch(path);
    await loadBranches();
    if (allBranches) await loadHistory(reset: true);
    return r;
  }

  Future<PullResult> pull({PullStrategy? strategy}) async {
    final r = await app.pull(path, strategy: strategy);
    await refresh();
    await loadHistory(reset: true);
    return r;
  }

  Future<PushResult> push() async {
    final r = await app.push(path);
    await loadBranches();
    return r;
  }

  // ---- history --------------------------------------------------------------

  static const pageSize = 100;

  Future<void> setAllBranches(bool v) async {
    allBranches = v;
    await loadHistory(reset: true);
  }

  Future<void> loadHistory({bool reset = false}) async {
    if (loadingHistory) return;
    if (reset) {
      history.clear();
      historyDone = false;
    }
    if (historyDone) return;
    loadingHistory = true;
    _notify();
    try {
      final page = await git.log(
        path,
        allBranches: allBranches,
        skip: history.length,
        limit: pageSize,
      );
      history.addAll(page);
      historyDone = page.length < pageSize;
      historyError = null;
    } catch (e) {
      historyError = describeError(e);
      historyDone = true;
    }
    loadingHistory = false;
    _notify();
  }
}
