import 'dart:io';

import 'package:clotho/core/git_service.dart';
import 'package:clotho/core/github_service.dart';
import 'package:clotho/core/token_store.dart';
import 'package:clotho/state/auth_controller.dart';
import 'package:clotho/state/github_scope.dart';
import 'package:clotho/src/rust/frb_generated.dart';
import 'package:clotho/state/app_controller.dart';
import 'package:clotho/ui/repo_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

Future<void> git(String dir, List<String> args) async {
  final r = await Process.run('git', args, workingDirectory: dir);
  if (r.exitCode != 0) throw StateError('git ${args.join(' ')}: ${r.stderr}');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());

  testWidgets('add a repo, commit through the UI with the real Rust core', (
    tester,
  ) async {
    final tmp = await Directory.systemTemp.createTemp('clotho_it');
    final repoDir = Directory('${tmp.path}/demo')..createSync();
    await git(repoDir.path, ['init', '-q', '-b', 'main']);
    await git(repoDir.path, ['config', 'user.name', 'IT']);
    await git(repoDir.path, ['config', 'user.email', 'it@example.com']);
    File('${repoDir.path}/hello.txt').writeAsStringSync('hello\n');

    final app = AppController(RustGitService(configDir: '${tmp.path}/config'));
    await app.init();
    final report = await app.addRepos([repoDir.path]);
    expect(report.added, hasLength(1));
    final path = report.added.single;

    await tester.binding.setSurfaceSize(const Size(1400, 900));
    const gh = RustGitHubService();
    await tester.pumpWidget(
      GitHubScope(
        auth: AuthController(github: gh, store: MemoryTokenStore()),
        github: gh,
        child: MaterialApp(
          home: RepoPage(app: app, path: path),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('hello.txt'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('commit-message')),
      'feat: first commit',
    );
    await tester.tap(find.byKey(const Key('commit-all')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('commit-button')));
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    final status = app.statusFor(path)!;
    expect(status.files, isEmpty);
    expect(find.text('Working tree clean. Nothing to commit.'), findsOneWidget);
    final log = await app.git.log(path);
    expect(log.single.summary, 'feat: first commit');

    app.dispose();
    await tmp.delete(recursive: true);
  });

  test('clone a repository with progress through the Rust core', () async {
    final tmp = await Directory.systemTemp.createTemp('clotho_clone');
    final src = Directory('${tmp.path}/src')..createSync();
    await git(src.path, ['init', '-q', '-b', 'main']);
    await git(src.path, ['config', 'user.name', 'IT']);
    await git(src.path, ['config', 'user.email', 'it@example.com']);
    File('${src.path}/a.txt').writeAsStringSync('a\n');
    await git(src.path, ['add', '.']);
    await git(src.path, ['commit', '-q', '-m', 'init']);

    const gh = RustGitHubService();
    final events = await gh.clone(src.path, '${tmp.path}/copy', null).toList();
    final done = events.last as CloneProgress_Done;
    expect(File('${done.path}/a.txt').existsSync(), isTrue);
    expect(await gh.remoteOf(done.path), isNull);

    await git(done.path, [
      'remote',
      'set-url',
      'origin',
      'https://github.com/octo/demo.git',
    ]);
    final remote = await gh.remoteOf(done.path);
    expect((remote!.owner, remote.repo), ('octo', 'demo'));
  });
}
