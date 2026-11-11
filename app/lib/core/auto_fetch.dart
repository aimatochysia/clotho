import 'package:clock/clock.dart';

import 'git_service.dart';

/// New upstream commits that an automatic fetch brought in.
class NewCommits {
  const NewCommits({
    required this.path,
    required this.name,
    required this.count,
    this.upstream,
  });

  final String path;
  final String name;
  final int count;

  /// For example `origin/main`.
  final String? upstream;

  String get title => name;
  String get body {
    final what = count == 1 ? '1 new commit' : '$count new commits';
    return upstream == null ? what : '$what on $upstream';
  }
}

/// Outcome of fetching one repository on schedule.
class AutoFetchResult {
  const AutoFetchResult(this.path, {this.error, this.newCommits});
  final String path;
  final Object? error;
  final NewCommits? newCommits;
}

/// Fetches every repository whose schedule is due, one after another, and
/// records the time so the next run waits a full interval. Used both by the
/// running app and by the Android background task.
///
/// [skip] lists repositories busy with something else right now; they stay
/// due and are picked up next time.
Future<List<AutoFetchResult>> runDueFetches(
  GitService git, {
  DateTime? now,
  Set<String> skip = const {},
}) async {
  final at = now ?? clock.now();
  final due = await git.dueForFetch(at);
  if (due.isEmpty) return const [];
  final registry = await git.loadRegistry();
  final names = {for (final r in registry.repos) r.path: r.name};
  final results = <AutoFetchResult>[];
  for (final path in due) {
    if (skip.contains(path)) continue;
    final before = await _behind(git, path);
    Object? error;
    try {
      await git.fetch(path);
    } catch (e) {
      error = e;
    }
    // Failed attempts count too, so an unreachable remote is retried on
    // schedule instead of every minute.
    try {
      await git.markAutoFetched(path, at);
    } catch (_) {}
    NewCommits? fresh;
    if (error == null) {
      final after = await git
          .status(path)
          .then<RepoStatus?>((s) => s, onError: (_) => null);
      final gained = (after?.behind ?? 0) - (before ?? 0);
      if (after != null && before != null && gained > 0) {
        fresh = NewCommits(
          path: path,
          name: names[path] ?? path,
          count: gained,
          upstream: after.upstream,
        );
      }
    }
    results.add(AutoFetchResult(path, error: error, newCommits: fresh));
  }
  return results;
}

Future<int?> _behind(GitService git, String path) async {
  try {
    return (await git.status(path)).behind;
  } catch (_) {
    return null;
  }
}
