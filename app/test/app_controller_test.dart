import 'package:clotho/core/auto_fetch.dart';
import 'package:clotho/core/background_fetch.dart';
import 'package:clotho/core/git_service.dart';
import 'package:clotho/core/notifications.dart';
import 'package:clotho/src/rust/error.dart';
import 'package:clotho/state/app_controller.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_git.dart';

const a = RepoEntry(
  path: '/r/a',
  name: 'a',
  fetchSchedule: FetchSchedule(
    enabled: true,
    every: 5,
    unit: FetchUnit.minutes,
  ),
);
const b = RepoEntry(
  path: '/r/b',
  name: 'b',
  fetchSchedule: fetchScheduleOff,
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

  test('auto fetch follows each schedule and skips repos with it off', () {
    fakeAsync((async) {
      final git = FakeGitService(repos: [a, b]);
      final app = AppController(git);
      app.init();
      async.flushMicrotasks();
      List<String> fetches() =>
          git.calls.where((c) => c.startsWith('fetch')).toList();
      expect(fetches(), ['fetch /r/a'], reason: 'due at start');
      async.elapse(const Duration(minutes: 4));
      async.flushMicrotasks();
      expect(fetches(), hasLength(1), reason: 'not due yet');
      async.elapse(const Duration(minutes: 1, seconds: 30));
      async.flushMicrotasks();
      expect(fetches(), ['fetch /r/a', 'fetch /r/a']);
      app.dispose();
    });
  });

  test('turning auto fetch off stops fetching', () {
    fakeAsync((async) {
      final git = FakeGitService(repos: [a]);
      final app = AppController(git);
      app.init();
      async.flushMicrotasks();
      app.updateRepo(a.copyWith(fetchSchedule: fetchScheduleOff));
      async.flushMicrotasks();
      git.calls.clear();
      async.elapse(const Duration(hours: 1));
      async.flushMicrotasks();
      expect(git.calls.where((c) => c.startsWith('fetch')), isEmpty);
      app.dispose();
    });
  });

  test('new upstream commits are notified, nothing else is', () async {
    final git = FakeGitService(repos: [a])..incoming['/r/a'] = 3;
    final notes = RecordingNotifier();
    final background = RecordingBackground();
    final app = AppController(git, notifier: notes, background: background);
    await app.init();
    await app.runAutoFetch();
    expect(notes.found, hasLength(1));
    expect(notes.found.single.name, 'a');
    expect(notes.found.single.body, '3 new commits on origin/main');
    expect(background.enabled, [true]);

    // Due again later, but nothing new upstream: no notification.
    await app.runAutoFetch(now: DateTime.now().add(const Duration(hours: 1)));
    expect(notes.found, hasLength(1));
    app.dispose();
  });

  test('background task follows whether any schedule is on', () async {
    final background = RecordingBackground();
    final app = AppController(
      FakeGitService(repos: [b]),
      background: background,
    );
    await app.init();
    await app.updateRepo(
      b.copyWith(
        fetchSchedule: const FetchSchedule(
          enabled: true,
          every: 2,
          unit: FetchUnit.days,
        ),
      ),
    );
    await app.updateRepo(b.copyWith(fetchSchedule: fetchScheduleOff));
    expect(background.enabled, [false, true, false]);
    app.dispose();
  });

  test('schedule labels and intervals', () {
    const s = FetchSchedule(enabled: true, every: 3, unit: FetchUnit.hours);
    expect(s.interval, const Duration(hours: 3));
    expect(s.label, 'every 3 hours');
    expect(fetchScheduleOff.label, 'every hour');
  });

  test('identity: repo choice, then default, then Git config', () async {
    const x = Identity(name: 'X', email: 'x@example.com');
    const y = Identity(name: 'Y', email: 'y@example.com');
    final git = FakeGitService(
      repos: [
        a,
        b.copyWith(identityEmail: 'Y@example.com'),
      ],
    );
    final app = AppController(git);
    await app.init();
    expect(app.identityFor('/r/a'), isNull, reason: 'none saved: Git config');
    await app.saveIdentity(x);
    await app.saveIdentity(y);
    expect(app.identityFor('/r/a'), x, reason: 'first one is the default');
    expect(app.identityFor('/r/b'), y, reason: 'repo override');
    await app.saveIdentity(y, makeDefault: true);
    expect(app.identityFor('/r/a'), y);
    app.dispose();
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

class RecordingNotifier implements FetchNotifier {
  final found = <NewCommits>[];
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> newCommits(List<NewCommits> f) async => found.addAll(f);
}

class RecordingBackground implements BackgroundFetch {
  final enabled = <bool>[];
  @override
  bool get supported => true;
  @override
  Future<bool> allowed() async => true;
  @override
  Future<bool> requestAllowed() async => true;
  @override
  Future<void> sync({required bool enabled}) async => this.enabled.add(enabled);
}
