import '../src/rust/api/branches.dart' as rb;
import '../src/rust/api/changes.dart' as rc;
import '../src/rust/api/history.dart' as rh;
import '../src/rust/api/registry.dart' as rr;
import '../src/rust/api/remote.dart' as rm;
import '../src/rust/api/repo.dart' as rp;
import '../src/rust/api/watch.dart' as rw;

import '../src/rust/api/branches.dart' show BranchInfo;
import '../src/rust/api/changes.dart' show CommitResult, FileDiff;
import '../src/rust/api/history.dart' show CommitInfo;
import '../src/rust/api/registry.dart'
    show AddReport, AppSettings, Registry, RepoEntry;
import '../src/rust/api/remote.dart'
    show AuthOptions, FetchResult, PullResult, PullStrategy, PushResult;
import '../src/rust/api/repo.dart' show RepoStatus;

export '../src/rust/api/branches.dart' show BranchInfo;
export '../src/rust/api/changes.dart'
    show CommitResult, DiffHunk, DiffLine, FileDiff, LineKind;
export '../src/rust/api/history.dart' show CommitInfo;
export '../src/rust/api/registry.dart'
    show AddReport, AppSettings, Registry, RepoEntry, SkippedPath;
export '../src/rust/api/remote.dart'
    show
        AuthOptions,
        FetchResult,
        PullOutcome,
        PullResult,
        PullStrategy,
        PushResult;
export '../src/rust/api/repo.dart'
    show ChangeKind, FileChange, RepoState, RepoStatus;

/// Everything the UI needs from the Rust core. Widgets and controllers depend
/// on this interface, so tests can swap in a fake without the native library.
abstract interface class GitService {
  Future<Registry> loadRegistry();
  Future<AddReport> addRepos(List<String> paths);
  Future<Registry> removeRepo(String path);
  Future<Registry> updateRepo(RepoEntry entry);
  Future<Registry> updateSettings(AppSettings settings);
  Future<List<String>> scanForRepos(String root, int maxDepth);

  Future<RepoStatus> status(String path);
  Future<FileDiff> diffFile(String path, String file, {required bool staged});
  Future<List<FileDiff>> commitDiff(String path, String oid);
  Future<void> stage(String path, List<String> files);
  Future<void> stageAll(String path);
  Future<void> unstage(String path, List<String> files);
  Future<void> discard(String path, List<String> files);
  Future<CommitResult> commit(
    String path,
    String message, {
    required bool stageAll,
    bool amend = false,
  });

  Future<List<BranchInfo>> branches(String path);
  Future<void> checkout(String path, String name);
  Future<void> createBranch(
    String path,
    String name, {
    String? startPoint,
    bool checkout = true,
  });
  Future<void> renameBranch(String path, String oldName, String newName);
  Future<void> deleteBranch(String path, String name, {bool force = false});

  Future<List<CommitInfo>> log(
    String path, {
    bool allBranches = false,
    int skip = 0,
    int limit = 100,
  });

  Future<FetchResult> fetch(String path);
  Future<PullResult> pull(String path, PullStrategy strategy);
  Future<PushResult> push(String path);

  /// Emits whenever files in the repository change. Cancel to stop.
  Stream<void> watch(String path);
  Future<void> unwatch(String path);
}

/// Production implementation backed by the Rust core.
class RustGitService implements GitService {
  RustGitService({required this.configDir, this.authProvider});

  final String configDir;

  /// Supplies credentials for remotes (filled in by GitHub sign-in later).
  final Future<AuthOptions> Function()? authProvider;

  Future<AuthOptions> _auth() async =>
      await authProvider?.call() ?? const AuthOptions();

  @override
  Future<Registry> loadRegistry() => rr.loadRegistry(configDir: configDir);
  @override
  Future<AddReport> addRepos(List<String> paths) =>
      rr.addRepos(configDir: configDir, paths: paths);
  @override
  Future<Registry> removeRepo(String path) =>
      rr.removeRepo(configDir: configDir, path: path);
  @override
  Future<Registry> updateRepo(RepoEntry entry) =>
      rr.updateRepo(configDir: configDir, entry: entry);
  @override
  Future<Registry> updateSettings(AppSettings settings) =>
      rr.updateSettings(configDir: configDir, settings: settings);
  @override
  Future<List<String>> scanForRepos(String root, int maxDepth) =>
      rp.scanForRepos(root: root, maxDepth: maxDepth);

  @override
  Future<RepoStatus> status(String path) => rp.repoStatus(path: path);
  @override
  Future<FileDiff> diffFile(String path, String file, {required bool staged}) =>
      rc.diffFile(path: path, file: file, staged: staged);
  @override
  Future<List<FileDiff>> commitDiff(String path, String oid) =>
      rc.commitDiff(path: path, oid: oid);
  @override
  Future<void> stage(String path, List<String> files) =>
      rc.stagePaths(path: path, files: files);
  @override
  Future<void> stageAll(String path) => rc.stageAll(path: path);
  @override
  Future<void> unstage(String path, List<String> files) =>
      rc.unstagePaths(path: path, files: files);
  @override
  Future<void> discard(String path, List<String> files) =>
      rc.discardPaths(path: path, files: files);
  @override
  Future<CommitResult> commit(
    String path,
    String message, {
    required bool stageAll,
    bool amend = false,
  }) => rc.commit(
    path: path,
    message: message,
    stageAllFirst: stageAll,
    amend: amend,
  );

  @override
  Future<List<BranchInfo>> branches(String path) => rb.listBranches(path: path);
  @override
  Future<void> checkout(String path, String name) =>
      rb.checkoutBranch(path: path, name: name);
  @override
  Future<void> createBranch(
    String path,
    String name, {
    String? startPoint,
    bool checkout = true,
  }) => rb.createBranch(
    path: path,
    name: name,
    startPoint: startPoint,
    checkout: checkout,
  );
  @override
  Future<void> renameBranch(String path, String oldName, String newName) =>
      rb.renameBranch(path: path, oldName: oldName, newName: newName);
  @override
  Future<void> deleteBranch(String path, String name, {bool force = false}) =>
      rb.deleteBranch(path: path, name: name, force: force);

  @override
  Future<List<CommitInfo>> log(
    String path, {
    bool allBranches = false,
    int skip = 0,
    int limit = 100,
  }) => rh.logPage(
    path: path,
    allBranches: allBranches,
    skip: skip,
    limit: limit,
  );

  @override
  Future<FetchResult> fetch(String path) async =>
      rm.fetchAll(path: path, auth: await _auth());
  @override
  Future<PullResult> pull(String path, PullStrategy strategy) async =>
      rm.pull(path: path, strategy: strategy, auth: await _auth());
  @override
  Future<PushResult> push(String path) async =>
      rm.push(path: path, auth: await _auth());

  @override
  Stream<void> watch(String path) => rw.watchRepo(path: path);
  @override
  Future<void> unwatch(String path) => rw.unwatchRepo(path: path);
}
