import 'dart:async';

import 'package:clotho/core/git_service.dart';

const defaultSettings = AppSettings(
  autoFetchMinutes: 5,
  pullStrategy: PullStrategy.fastForwardOnly,
  pushAfterCommit: false,
  scanDepth: 3,
  checkUpdates: true,
);

RepoStatus statusWith({
  String path = '/repos/demo',
  String branch = 'main',
  List<FileChange> files = const [],
  int ahead = 0,
  int behind = 0,
  String? upstream = 'origin/main',
}) => RepoStatus(
  path: path,
  branch: branch,
  headShortOid: 'abc1234',
  upstream: upstream,
  ahead: ahead,
  behind: behind,
  state: RepoState.clean,
  files: files,
  stagedCount: files.where((f) => f.staged != null).length,
  unstagedCount: files.where((f) => f.unstaged != null).length,
  conflictedCount: files.where((f) => f.conflicted).length,
);

const modifiedFile = FileChange(
  path: 'lib/a.dart',
  unstaged: ChangeKind.modified,
  conflicted: false,
);
const stagedFile = FileChange(
  path: 'lib/b.dart',
  staged: ChangeKind.modified,
  conflicted: false,
);

/// In-memory GitService that records calls.
class FakeGitService implements GitService {
  FakeGitService({
    List<RepoEntry>? repos,
    AppSettings settings = defaultSettings,
  }) : registry = Registry(settings: settings, repos: repos ?? []);

  Registry registry;
  final Map<String, RepoStatus> statuses = {};
  final Map<String, Object> fetchErrors = {};
  final List<String> calls = [];
  final _watchers = <String, StreamController<void>>{};

  @override
  Future<Registry> loadRegistry() async => registry;

  @override
  Future<AddReport> addRepos(List<String> paths) async {
    calls.add('add ${paths.join(',')}');
    final added = <String>[];
    final repos = [...registry.repos];
    for (final p in paths) {
      if (repos.any((r) => r.path == p)) continue;
      repos.add(RepoEntry(path: p, name: p.split('/').last, autoFetch: true));
      added.add(p);
    }
    registry = Registry(settings: registry.settings, repos: repos);
    return AddReport(registry: registry, added: added, skipped: const []);
  }

  @override
  Future<Registry> removeRepo(String path) async {
    registry = Registry(
      settings: registry.settings,
      repos: registry.repos.where((r) => r.path != path).toList(),
    );
    return registry;
  }

  @override
  Future<Registry> updateRepo(RepoEntry entry) async {
    registry = Registry(
      settings: registry.settings,
      repos: [for (final r in registry.repos) r.path == entry.path ? entry : r],
    );
    return registry;
  }

  @override
  Future<Registry> updateSettings(AppSettings settings) async {
    calls.add('settings');
    registry = Registry(settings: settings, repos: registry.repos);
    return registry;
  }

  @override
  Future<List<String>> scanForRepos(String root, int maxDepth) async => [];

  @override
  Future<RepoStatus> status(String path) async =>
      statuses[path] ?? statusWith(path: path);

  @override
  Future<FileDiff> diffFile(
    String path,
    String file, {
    required bool staged,
  }) async => FileDiff(
    path: file,
    isBinary: false,
    truncated: false,
    additions: 1,
    deletions: 1,
    hunks: const [
      DiffHunk(
        header: '@@ -1 +1 @@',
        lines: [
          DiffLine(kind: LineKind.removed, oldLineno: 1, content: 'old line'),
          DiffLine(kind: LineKind.added, newLineno: 1, content: 'new line'),
        ],
      ),
    ],
  );

  @override
  Future<List<FileDiff>> commitDiff(String path, String oid) async => [];

  void _update(String path, RepoStatus Function(RepoStatus) f) {
    statuses[path] = f(statuses[path] ?? statusWith(path: path));
  }

  @override
  Future<void> stage(String path, List<String> files) async {
    calls.add('stage ${files.join(',')}');
    _update(path, (s) {
      final next = [
        for (final f in s.files)
          files.contains(f.path)
              ? FileChange(
                  path: f.path,
                  staged: f.unstaged ?? f.staged,
                  conflicted: false,
                )
              : f,
      ];
      return statusWith(
        path: path,
        files: next,
        ahead: s.ahead,
        behind: s.behind,
      );
    });
  }

  @override
  Future<void> stageAll(String path) async {
    final s = await status(path);
    await stage(path, [for (final f in s.files) f.path]);
  }

  @override
  Future<void> unstage(String path, List<String> files) async =>
      calls.add('unstage');

  @override
  Future<void> discard(String path, List<String> files) async =>
      calls.add('discard');

  @override
  Future<CommitResult> commit(
    String path,
    String message, {
    required bool stageAll,
    bool amend = false,
  }) async {
    calls.add('commit "$message" stageAll=$stageAll');
    final s = await status(path);
    statuses[path] = statusWith(path: path, ahead: s.ahead + 1);
    return CommitResult(
      oid: 'deadbeef' * 5,
      shortOid: 'deadbee',
      summary: message,
    );
  }

  @override
  Future<List<BranchInfo>> branches(String path) async => [
    BranchInfo(
      name: 'main',
      isRemote: false,
      isHead: true,
      upstream: 'origin/main',
      ahead: 0,
      behind: 0,
      shortOid: 'abc1234',
      summary: 'init',
      time: 0,
    ),
  ];

  @override
  Future<void> checkout(String path, String name) async =>
      calls.add('checkout $name');
  @override
  Future<void> createBranch(
    String path,
    String name, {
    String? startPoint,
    bool checkout = true,
  }) async => calls.add('create $name');
  @override
  Future<void> renameBranch(
    String path,
    String oldName,
    String newName,
  ) async => calls.add('rename');
  @override
  Future<void> deleteBranch(
    String path,
    String name, {
    bool force = false,
  }) async => calls.add('delete');

  @override
  Future<List<CommitInfo>> log(
    String path, {
    bool allBranches = false,
    int skip = 0,
    int limit = 100,
  }) async => [];

  @override
  Future<FetchResult> fetch(String path) async {
    calls.add('fetch $path');
    final err = fetchErrors[path];
    if (err != null) throw err;
    return const FetchResult(remotes: ['origin'], receivedObjects: 0);
  }

  @override
  Future<PullResult> pull(String path, PullStrategy strategy) async {
    calls.add('pull ${strategy.name}');
    return const PullResult(outcome: PullOutcome.upToDate, newCommits: 0);
  }

  @override
  Future<PushResult> push(String path) async {
    calls.add('push');
    _update(path, (s) => statusWith(path: path, files: s.files));
    return const PushResult(
      remote: 'origin',
      branch: 'main',
      setUpstream: false,
    );
  }

  @override
  Stream<void> watch(String path) =>
      (_watchers[path] = StreamController<void>()).stream;

  @override
  Future<void> unwatch(String path) async => _watchers.remove(path)?.close();
}
