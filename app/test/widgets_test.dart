import 'package:clotho/app.dart';
import 'package:clotho/core/git_service.dart';
import 'package:clotho/state/app_controller.dart';
import 'package:clotho/ui/repo_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_git.dart';

const repo = RepoEntry(path: '/repos/demo', name: 'demo', autoFetch: true);

Future<AppController> boot(FakeGitService git) async {
  final app = AppController(git);
  await app.init();
  return app;
}

Future<void> openRepo(WidgetTester tester, AppController app) async {
  await tester.binding.setSurfaceSize(const Size(1400, 900));
  await tester.pumpWidget(
    MaterialApp(
      home: RepoPage(app: app, path: repo.path),
    ),
  );
  await tester.pumpAndSettle();
}

FilledButton commitButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byKey(const Key('commit-button')));

void main() {
  testWidgets('empty dashboard explains how to start', (tester) async {
    final app = await boot(FakeGitService());
    await tester.pumpWidget(ClothoApp(app: app));
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
    await tester.pumpWidget(ClothoApp(app: app));
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
    expect(git.calls, contains('commit "fix: thing" stageAll=true'));
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
        autoFetchMinutes: 0,
        pullStrategy: PullStrategy.merge,
        pushAfterCommit: true,
        scanDepth: 3,
        checkUpdates: false,
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
}
