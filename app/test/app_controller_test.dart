import 'package:clotho/core/git_service.dart';
import 'package:clotho/src/rust/error.dart';
import 'package:clotho/state/app_controller.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_git.dart';

const a = RepoEntry(path: '/r/a', name: 'a', autoFetch: true);
const b = RepoEntry(
  path: '/r/b',
  name: 'b',
  autoFetch: false,
  pullStrategy: PullStrategy.rebase,
  pushAfterCommit: true,
);

void main() {
  test('per-repo overrides win over app defaults', () async {
    final app = AppController(FakeGitService(repos: [a, b]));
    await app.init();
    expect(app.pullStrategyFor('/r/a'), PullStrategy.fastForwardOnly);
    expect(app.pullStrategyFor('/r/b'), PullStrategy.rebase);
    expect(app.pushAfterCommitFor('/r/a'), isFalse);
    expect(app.pushAfterCommitFor('/r/b'), isTrue);
    app.dispose();
  });

  test('fetch all records failures per repo and keeps going', () async {
    final git = FakeGitService(repos: [a, b])
      ..fetchErrors['/r/a'] = const CoreError.auth(message: 'bad token');
    final app = AppController(git);
    await app.init();
    await app.fetchAll();
    expect(git.calls, containsAll(['fetch /r/a', 'fetch /r/b']));
    expect(
      app.repos.firstWhere((r) => r.entry.path == '/r/a').fetchError,
      contains('bad token'),
    );
    expect(
      app.repos.firstWhere((r) => r.entry.path == '/r/b').fetchError,
      isNull,
    );
    app.dispose();
  });

  test('auto fetch runs on the interval and skips opted-out repos', () {
    fakeAsync((async) {
      final git = FakeGitService(repos: [a, b]);
      final app = AppController(git);
      app.init();
      async.flushMicrotasks();
      expect(git.calls.where((c) => c.startsWith('fetch')), isEmpty);
      async.elapse(const Duration(minutes: 5, seconds: 1));
      async.flushMicrotasks();
      expect(git.calls.where((c) => c.startsWith('fetch')), ['fetch /r/a']);
      app.dispose();
    });
  });

  test('turning auto fetch off stops the timer', () {
    fakeAsync((async) {
      final git = FakeGitService(repos: [a]);
      final app = AppController(git);
      app.init();
      async.flushMicrotasks();
      app.updateSettings(
        const AppSettings(
          autoFetchMinutes: 0,
          pullStrategy: PullStrategy.merge,
          pushAfterCommit: false,
          scanDepth: 3,
          checkUpdates: true,
        ),
      );
      async.flushMicrotasks();
      async.elapse(const Duration(hours: 1));
      async.flushMicrotasks();
      expect(git.calls.where((c) => c.startsWith('fetch')), isEmpty);
      app.dispose();
    });
  });

  test('pull uses the effective strategy', () async {
    final git = FakeGitService(repos: [a, b]);
    final app = AppController(git);
    await app.init();
    await app.pull('/r/b');
    await app.pull('/r/a');
    expect(git.calls.where((c) => c.startsWith('pull')), [
      'pull rebase',
      'pull fastForwardOnly',
    ]);
    app.dispose();
  });
}
