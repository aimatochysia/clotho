import 'dart:typed_data';

import 'package:clotho/app.dart';
import 'package:clotho/core/git_service.dart';
import 'package:clotho/state/app_controller.dart';
import 'package:clotho/state/update_controller.dart';
import 'package:clotho/core/github_service.dart';
import 'package:clotho/ui/github/repos_page.dart';
import 'package:clotho/ui/repo_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clotho/ui/widgets/binary_preview.dart';

import 'fake_git.dart';
import 'fake_github.dart';
import 'fake_update.dart';

const repo = RepoEntry(
  path: '/repos/demo',
  name: 'demo',
  fetchSchedule: fetchScheduleOff,
);

Future<AppController> boot(FakeGitService git) async {
  final app = AppController(git);
  await app.init();
  return app;
}

Future<void> openRepo(WidgetTester tester, AppController app) async {
  await tester.binding.setSurfaceSize(const Size(1400, 900));
  await tester.pumpWidget(
    scoped(
      MaterialApp(
        home: RepoPage(app: app, path: repo.path),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

FilledButton commitButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byKey(const Key('commit-button')));

extension on AppController {
  Widget wrap({FakeGitHubService? gh}) {
    final g = gh ?? FakeGitHubService();
    return ClothoApp(app: this, auth: fakeAuth(g), github: g);
  }
}

void main() {
  testWidgets('empty dashboard explains how to start', (tester) async {
    final app = await boot(FakeGitService());
    await tester.pumpWidget(app.wrap());
    await tester.pumpAndSettle();
    expect(find.text('No repositories yet'), findsOneWidget);
    expect(find.text('Scan folder'), findsOneWidget);
    app.dispose();
  });

  testWidgets('dashboard shows branch, ahead/behind and change count', (
    tester,
  ) async {
    final git = FakeGitService(repos: [repo])
      ..statuses[repo.path] = statusWith(
        files: [modifiedFile],
        ahead: 2,
        behind: 1,
      );
    final app = await boot(git);
    await tester.pumpWidget(app.wrap());
    await tester.pumpAndSettle();
    expect(find.text('demo'), findsOneWidget);
    expect(find.text('main'), findsOneWidget);
    expect(find.text('↑2'), findsOneWidget);
    expect(find.text('↓1'), findsOneWidget);
    expect(find.text('1 changed'), findsOneWidget);
    app.dispose();
  });

  testWidgets('commit is disabled when there is nothing to commit', (
    tester,
  ) async {
    final app = await boot(FakeGitService(repos: [repo]));
    await openRepo(tester, app);
    await tester.enterText(find.byKey(const Key('commit-message')), 'feat: x');
    await tester.pump();
    expect(commitButton(tester).onPressed, isNull);
    expect(find.text('No changes to commit'), findsOneWidget);
    app.dispose();
  });

  testWidgets('unstaged changes need staging or "commit all"', (tester) async {
    final git = FakeGitService(repos: [repo])
      ..statuses[repo.path] = statusWith(files: [modifiedFile]);
    final app = await boot(git);
    await openRepo(tester, app);
    await tester.enterText(
      find.byKey(const Key('commit-message')),
      'fix: thing',
    );
    await tester.pump();
    expect(commitButton(tester).onPressed, isNull);

    await tester.tap(find.byKey(const Key('commit-all')));
    await tester.pump();
    expect(commitButton(tester).onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('commit-button')));
    await tester.pumpAndSettle();
    expect(
      git.calls,
      contains('commit "fix: thing" stageAll=true as config@example.com'),
    );
    expect(git.calls, isNot(contains('push')));
    expect(find.textContaining('Committed deadbee'), findsOneWidget);
    app.dispose();
  });

  testWidgets('staging a file enables commit; message is required', (
    tester,
  ) async {
    final git = FakeGitService(repos: [repo])
      ..statuses[repo.path] = statusWith(files: [modifiedFile]);
    final app = await boot(git);
    await openRepo(tester, app);
    await tester.tap(find.byKey(const Key('stage-lib/a.dart')));
    await tester.pumpAndSettle();
    expect(git.calls, contains('stage lib/a.dart'));
    expect(commitButton(tester).onPressed, isNull, reason: 'no message yet');
    await tester.enterText(find.byKey(const Key('commit-message')), 'feat: a');
    await tester.pump();
    expect(commitButton(tester).onPressed, isNotNull);
    app.dispose();
  });

  testWidgets('push after commit setting pushes automatically', (tester) async {
    final git = FakeGitService(
      repos: [repo],
      settings: const AppSettings(
        pullStrategy: PullStrategy.merge,
        pushAfterCommit: true,
        scanDepth: 3,
        checkUpdates: false,
        identities: [],
        defaultIdentity: 0,
      ),
    )..statuses[repo.path] = statusWith(files: [stagedFile]);
    final app = await boot(git);
    await openRepo(tester, app);
    expect(find.text('Commit & push'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('commit-message')), 'feat: b');
    await tester.pump();
    await tester.tap(find.byKey(const Key('commit-button')));
    await tester.pumpAndSettle();
    expect(
      git.calls.indexOf('push'),
      greaterThan(git.calls.indexWhere((c) => c.startsWith('commit'))),
    );
    expect(find.textContaining('and pushed to origin/main'), findsOneWidget);
    app.dispose();
  });

  testWidgets('selecting a file shows its diff', (tester) async {
    final git = FakeGitService(repos: [repo])
      ..statuses[repo.path] = statusWith(files: [modifiedFile]);
    final app = await boot(git);
    await openRepo(tester, app);
    await tester.tap(find.byKey(const Key('file-u-lib/a.dart')));
    await tester.pumpAndSettle();
    expect(find.text('+ new line'), findsOneWidget);
    expect(find.text('- old line'), findsOneWidget);
    app.dispose();
  });

  testWidgets('pull button uses the configured strategy', (tester) async {
    final git = FakeGitService(repos: [repo]);
    final app = await boot(git);
    await openRepo(tester, app);
    await tester.tap(find.byKey(const Key('pull')));
    await tester.pumpAndSettle();
    expect(git.calls, contains('pull fastForwardOnly'));
    expect(find.text('Already up to date'), findsOneWidget);
    app.dispose();
  });

  testWidgets('sign in with a personal access token', (tester) async {
    final gh = FakeGitHubService();
    final auth = fakeAuth(gh);
    await auth.init();
    final app = await boot(FakeGitService());
    await tester.pumpWidget(ClothoApp(app: app, auth: auth, github: gh));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sign-in')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Access token'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('pat-field')), 'wrong');
    await tester.tap(find.byKey(const Key('pat-submit')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sign-in to the remote failed'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('pat-field')), 'good');
    await tester.tap(find.byKey(const Key('pat-submit')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(auth.user?.login, 'octo');
    expect(find.byKey(const Key('account')), findsOneWidget);
    app.dispose();
  });

  testWidgets('browser sign-in shows the device code', (tester) async {
    final gh = FakeGitHubService();
    final auth = fakeAuth(gh);
    await auth.init();
    final app = await boot(FakeGitService());
    await tester.pumpWidget(ClothoApp(app: app, auth: auth, github: gh));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sign-in')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('browser-start')));
    await tester.pump();
    await tester.pump();
    expect(find.text('ABCD-1234'), findsOneWidget);
    expect(find.text('Waiting for approval…'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(auth.pending, isNull);
    app.dispose();
  });

  testWidgets('GitHub tab lists pull requests for a GitHub remote', (
    tester,
  ) async {
    final git = FakeGitService(repos: [repo])
      ..statuses[repo.path] = statusWith();
    final app = await boot(git);
    final gh = FakeGitHubService()
      ..remote = const GitHubRemote(
        remote: 'origin',
        owner: 'octo',
        repo: 'demo',
      )
      ..pullList = const [
        GitHubPull(
          number: 7,
          title: 'Add feature',
          author: 'octo',
          state: 'open',
          draft: false,
          htmlUrl: 'https://github.com/octo/demo/pull/7',
          headRef: 'feature',
          baseRef: 'main',
          updatedAt: '2026-11-11T10:00:00Z',
        ),
      ];
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    await tester.pumpWidget(
      scoped(
        MaterialApp(
          home: RepoPage(app: app, path: repo.path),
        ),
        gh: gh,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('GitHub'));
    await tester.pumpAndSettle();
    expect(find.text('Add feature  #7'), findsOneWidget);
    expect(find.text('New pull request'), findsOneWidget);
    app.dispose();
  });

  testWidgets('repository browser hides archived repositories', (tester) async {
    final gh = FakeGitHubService()
      ..repoList = [ghRepo('alpha'), ghRepo('old', archived: true)];
    final auth = fakeAuth(gh, token: 'good');
    await auth.init();
    final app = await boot(FakeGitService());
    await tester.pumpWidget(
      scoped(
        MaterialApp(home: GitHubReposPage(app: app)),
        gh: gh,
        auth: auth,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('octo/alpha'), findsOneWidget);
    expect(find.text('octo/old'), findsNothing);
    await tester.tap(find.text('Hide archived'));
    await tester.pumpAndSettle();
    expect(find.text('octo/old'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('gh-filter')), 'alp');
    await tester.pumpAndSettle();
    expect(find.text('octo/old'), findsNothing);
    app.dispose();
  });

  testWidgets('update banner opens the dialog and verifies the download', (
    tester,
  ) async {
    final svc = FakeUpdateService()..next = updateInfo();
    final updates = UpdateController(service: svc, currentVersion: '0.1.0');
    await updates.check();
    final git = FakeGitService(repos: [repo])
      ..statuses[repo.path] = statusWith();
    final app = await boot(git);
    final gh = FakeGitHubService();
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    await tester.pumpWidget(
      ClothoApp(app: app, auth: fakeAuth(gh), github: gh, updates: updates),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Clotho 0.2.0 is available'), findsOneWidget);
    await tester.tap(find.byKey(const Key('update-view')));
    await tester.pumpAndSettle();
    expect(find.textContaining('shiny'), findsOneWidget);
    await tester.tap(find.byKey(const Key('update-download')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Signature and SHA-256 verified'),
      findsOneWidget,
    );
    expect(
      find.text('sudo apt install "/tmp/clotho-0.2.0-linux-amd64.deb"'),
      findsOneWidget,
    );
    app.dispose();
  });

  testWidgets('repository settings turn on a whole-number fetch schedule', (
    tester,
  ) async {
    final git = FakeGitService(repos: [repo]);
    final app = await boot(git);
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    await tester.pumpWidget(app.wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Repository settings').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('auto-fetch-every')), findsNothing);
    await tester.tap(find.byKey(const Key('auto-fetch')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('auto-fetch-every')), '1.5');
    await tester.pump();
    expect(find.text('15'), findsOneWidget, reason: 'digits only');
    await tester.enterText(find.byKey(const Key('auto-fetch-every')), '30');
    await tester.tap(find.byKey(const Key('auto-fetch-unit')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('minutes').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Turning it on explains notifications first.
    expect(find.text('Stay up to date'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    final saved = git.registry.repos.single.fetchSchedule;
    expect(saved.enabled, isTrue);
    expect(saved.every, 30);
    expect(saved.unit, FetchUnit.minutes);
    app.dispose();
  });

  testWidgets('first commit without an identity asks for one and retries', (
    tester,
  ) async {
    // The commit button spins while the dialog is open, so pump a fixed time.
    Future<void> settle(WidgetTester t) async {
      for (var i = 0; i < 10; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
    }

    final git = FakeGitService(repos: [repo])
      ..configIdentity = null
      ..statuses[repo.path] = statusWith(files: [stagedFile]);
    final app = await boot(git);
    await openRepo(tester, app);
    await tester.enterText(find.byKey(const Key('commit-message')), 'feat: a');
    await tester.pump();
    await tester.tap(find.byKey(const Key('commit-button')));
    await settle(tester);

    expect(find.text('Who is committing?'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('identity-name')), 'Hael');
    await tester.enterText(find.byKey(const Key('identity-email')), 'nope');
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(find.text('Enter an email address'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('identity-email')),
      'hael@example.com',
    );
    await tester.tap(find.text('Save'));
    await settle(tester);

    expect(
      git.calls,
      contains('commit "feat: a" stageAll=false as hael@example.com'),
    );
    expect(app.settings.identities.single.name, 'Hael');
    app.dispose();
  });

  testWidgets('binary images get a before and after preview', (tester) async {
    // 1x1 transparent PNG.
    final png = Uint8List.fromList(const [
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
      0x00,
      0x00,
      0x00,
      0x0D,
      0x49,
      0x48,
      0x44,
      0x52,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x01,
      0x08,
      0x06,
      0x00,
      0x00,
      0x00,
      0x1F,
      0x15,
      0xC4,
      0x89,
      0x00,
      0x00,
      0x00,
      0x0D,
      0x49,
      0x44,
      0x41,
      0x54,
      0x78,
      0x9C,
      0x63,
      0x00,
      0x01,
      0x00,
      0x00,
      0x05,
      0x00,
      0x01,
      0x0D,
      0x0A,
      0x2D,
      0xB4,
      0x00,
      0x00,
      0x00,
      0x00,
      0x49,
      0x45,
      0x4E,
      0x44,
      0xAE,
      0x42,
      0x60,
      0x82,
    ]);
    const sprite = FileChange(
      path: 'art/hero.png',
      unstaged: ChangeKind.modified,
      conflicted: false,
    );
    final git = FakeGitService(repos: [repo])
      ..statuses[repo.path] = statusWith(files: [sprite])
      ..binaryFiles.add('art/hero.png')
      ..oldBytes = png
      ..newBytes = png;
    final app = await boot(git);
    await openRepo(tester, app);
    await tester.tap(find.byKey(const Key('file-u-art/hero.png')));
    await tester.pumpAndSettle();
    expect(find.text('Before'), findsOneWidget);
    expect(find.text('After'), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(2));

    // A watcher refresh with unchanged bytes keeps the same images on screen:
    // no spinner, no new image widgets.
    final before = tester.widgetList<Image>(find.byType(Image)).toList();
    final page = tester.state(find.byType(RepoPage));
    await (page as dynamic).repo.refresh();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pumpAndSettle();
    final after = tester.widgetList<Image>(find.byType(Image)).toList();
    expect(after.map((i) => i.image), before.map((i) => i.image));
    app.dispose();
  });

  test('preview kind comes from the extension', () {
    expect(previewKindFor('a/B.PNG'), PreviewKind.image);
    expect(previewKindFor('hero.aseprite'), PreviewKind.aseprite);
    expect(previewKindFor('song.mp3'), PreviewKind.none);
    expect(describeBinary('song.mp3'), 'Audio');
    expect(describeBinary('thing.xyz'), '.xyz file');
  });
}
