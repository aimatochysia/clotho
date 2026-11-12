import 'dart:typed_data';

import '../src/rust/api/branches.dart' as rb;
import '../src/rust/api/changes.dart' as rc;
import '../src/rust/api/history.dart' as rh;
import '../src/rust/api/identity.dart' as ri;
import '../src/rust/api/preview.dart' as rv;
import '../src/rust/api/registry.dart' as rr;
import '../src/rust/api/remote.dart' as rm;
import '../src/rust/api/repo.dart' as rp;
import '../src/rust/api/undo.dart' as ru;
import '../src/rust/api/watch.dart' as rw;

import '../src/rust/api/branches.dart' show BranchInfo;
import '../src/rust/api/changes.dart' show CommitResult, FileDiff;
import '../src/rust/api/history.dart' show CommitInfo;
import '../src/rust/api/identity.dart' show Identity;
import '../src/rust/api/preview.dart' show FileVersions;
import '../src/rust/api/registry.dart'
    show AddReport, AppSettings, FetchSchedule, FetchUnit, Registry, RepoEntry;
import '../src/rust/api/remote.dart'
    show AuthOptions, FetchResult, PullResult, PullStrategy, PushResult;
import '../src/rust/api/repo.dart' show RepoStatus;
import '../src/rust/api/undo.dart' show UndoPlan, UndoResult;

export '../src/rust/api/branches.dart' show BranchInfo;
export '../src/rust/api/changes.dart'
    show CommitResult, DiffHunk, DiffLine, FileDiff, LineKind;
export '../src/rust/api/history.dart' show CommitInfo;
export '../src/rust/api/identity.dart' show Identity;
export '../src/rust/api/preview.dart' show FileSide, FileVersions;
export '../src/rust/api/undo.dart' show UndoKind, UndoPlan, UndoResult;
export '../src/rust/api/registry.dart'
    show
        AddReport,
        AppSettings,
        FetchSchedule,
        FetchUnit,
        Registry,
        RepoEntry,
        SkippedPath;
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

extension AppSettingsCopy on AppSettings {
  AppSettings copyWith({
    PullStrategy? pullStrategy,
    bool? pushAfterCommit,
    int? scanDepth,
    bool? checkUpdates,
    String? cloneDir,
    List<Identity>? identities,
    int? defaultIdentity,
  }) => AppSettings(
    pullStrategy: pullStrategy ?? this.pullStrategy,
    pushAfterCommit: pushAfterCommit ?? this.pushAfterCommit,
    scanDepth: scanDepth ?? this.scanDepth,
    checkUpdates: checkUpdates ?? this.checkUpdates,
    cloneDir: cloneDir ?? this.cloneDir,
    identities: identities ?? this.identities,
    defaultIdentity: defaultIdentity ?? this.defaultIdentity,
  );
}

const fetchScheduleOff = FetchSchedule(
  enabled: false,
  every: 1,
  unit: FetchUnit.hours,
);

extension FetchScheduleTime on FetchSchedule {
  Duration get interval => switch (unit) {
    FetchUnit.minutes => Duration(minutes: every),
    FetchUnit.hours => Duration(hours: every),
    FetchUnit.days => Duration(days: every),
  };

  /// "every 2 hours", "every minute".
  String get label {
    final word = switch (unit) {
      FetchUnit.minutes => 'minute',
      FetchUnit.hours => 'hour',
      FetchUnit.days => 'day',
    };
    return every == 1 ? 'every $word' : 'every $every ${word}s';
  }
}

const _keep = Object();

extension RepoEntryCopy on RepoEntry {
  /// Pass `identityEmail: null` to go back to the default identity.
  RepoEntry copyWith({
    String? name,
    FetchSchedule? fetchSchedule,
    Object? identityEmail = _keep,
  }) => RepoEntry(
    path: path,
    name: name ?? this.name,
    pullStrategy: pullStrategy,
    pushAfterCommit: pushAfterCommit,
    fetchSchedule: fetchSchedule ?? this.fetchSchedule,
    lastAutoFetch: lastAutoFetch,
    identityEmail: identical(identityEmail, _keep)
        ? this.identityEmail
        : identityEmail as String?,
  );
}

extension IdentityText on Identity {
  String get label => '$name <$email>';
}

/// Everything the UI needs from the Rust core. Widgets and controllers depend
/// on this interface, so tests can swap in a fake without the native library.
abstract interface class GitService {
  Future<Registry> loadRegistry();
  Future<AddReport> addRepos(List<String> paths);
  Future<Registry> removeRepo(String path);
  Future<Registry> updateRepo(RepoEntry entry);
  Future<Registry> updateSettings(AppSettings settings);
  Future<List<String>> scanForRepos(String root, int maxDepth);

  /// Repositories whose automatic fetch is due at [now].
  Future<List<String>> dueForFetch(DateTime now);
  Future<void> markAutoFetched(String path, DateTime at);

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
    Identity? identity,
  });

  /// Who Git itself would commit as in [path] (or globally when null).
  Future<Identity?> gitIdentity(String? path);

  /// Both sides of a change, for previews of binary files.
  Future<FileVersions> workingFileVersions(
    String path,
    String file, {
    required bool staged,
  });
  Future<FileVersions> commitFileVersions(
    String path,
    String oid,
    String file, {
    String? oldPath,
  });

  /// First frame of an Aseprite sprite as PNG bytes.
  Future<Uint8List> renderAseprite(Uint8List data);

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

  /// How [oid] would be undone: taken back (not pushed, newest) or cancelled
  /// with a new commit.
  Future<UndoPlan> planUndo(String path, String oid);
  Future<UndoResult> undoCommit(String path, String oid, {Identity? identity});

  /// Puts back a commit taken back by [undoCommit]; returns its id.
  Future<String> redoUndo(String path, String backup);

  Future<List<CommitInfo>> log(
    String path, {
    bool allBranches = false,
    int skip = 0,
    int limit = 100,
  });

  Future<FetchResult> fetch(String path);
  Future<PullResult> pull(
    String path,
    PullStrategy strategy, {
    Identity? identity,
  });
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
  Future<List<String>> dueForFetch(DateTime now) => rr.dueForFetch(
    configDir: configDir,
    nowSeconds: now.millisecondsSinceEpoch ~/ 1000,
  );
  @override
  Future<void> markAutoFetched(String path, DateTime at) => rr.markAutoFetched(
    configDir: configDir,
    path: path,
    atSeconds: at.millisecondsSinceEpoch ~/ 1000,
  );

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
    Identity? identity,
  }) => rc.commit(
    path: path,
    message: message,
    stageAllFirst: stageAll,
    amend: amend,
    identity: identity,
  );

  @override
  Future<Identity?> gitIdentity(String? path) => ri.gitIdentity(path: path);

  @override
  Future<FileVersions> workingFileVersions(
    String path,
    String file, {
    required bool staged,
  }) => rv.workingFileVersions(path: path, file: file, staged: staged);

  @override
  Future<FileVersions> commitFileVersions(
    String path,
    String oid,
    String file, {
    String? oldPath,
  }) =>
      rv.commitFileVersions(path: path, oid: oid, file: file, oldPath: oldPath);

  @override
  Future<Uint8List> renderAseprite(Uint8List data) =>
      rv.renderAseprite(data: data);

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
  Future<UndoPlan> planUndo(String path, String oid) =>
      ru.planUndo(path: path, oid: oid);
  @override
  Future<UndoResult> undoCommit(
    String path,
    String oid, {
    Identity? identity,
  }) => ru.undoCommit(path: path, oid: oid, identity: identity);
  @override
  Future<String> redoUndo(String path, String backup) =>
      ru.redoUndo(path: path, backup: backup);

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
  Future<PullResult> pull(
    String path,
    PullStrategy strategy, {
    Identity? identity,
  }) async => rm.pull(
    path: path,
    strategy: strategy,
    auth: await _auth(),
    identity: identity,
  );
  @override
  Future<PushResult> push(String path) async =>
      rm.push(path: path, auth: await _auth());

  @override
  Stream<void> watch(String path) => rw.watchRepo(path: path);
  @override
  Future<void> unwatch(String path) => rw.unwatchRepo(path: path);
}
