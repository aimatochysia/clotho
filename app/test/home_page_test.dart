import 'package:clotho/app.dart';
import 'package:clotho/home/repo_inspector.dart';
import 'package:clotho/src/rust/api/repo.dart';
import 'package:clotho/src/rust/error.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeInspector implements RepoInspector {
  _FakeInspector(this.result);
  final InspectResult result;
  String? lastPath;

  @override
  Future<InspectResult> inspect(String path) async {
    lastPath = path;
    return result;
  }
}

Widget _app(RepoInspector inspector) => ClothoApp(
  coreVersion: '0.1.0',
  libgit2Version: '1.9.0',
  inspector: inspector,
);

void main() {
  testWidgets('shows core and libgit2 versions', (tester) async {
    await tester.pumpWidget(_app(_FakeInspector(const InspectFailed('x'))));
    expect(find.text('Core 0.1.0 · libgit2 1.9.0'), findsOneWidget);
  });

  testWidgets('shows branch for a found repository', (tester) async {
    final inspector = _FakeInspector(
      const InspectFound(
        RepoInfo(
          path: '/repos/demo',
          branch: 'main',
          isBare: false,
          isEmpty: false,
        ),
      ),
    );
    await tester.pumpWidget(_app(inspector));
    await tester.enterText(
      find.byKey(const Key('path-field')),
      ' /repos/demo ',
    );
    await tester.tap(find.byKey(const Key('inspect-button')));
    await tester.pumpAndSettle();

    expect(inspector.lastPath, '/repos/demo');
    expect(find.text('/repos/demo'), findsOneWidget);
    expect(find.text('Branch: main'), findsOneWidget);
  });

  testWidgets('empty path does nothing', (tester) async {
    final inspector = _FakeInspector(const InspectFailed('x'));
    await tester.pumpWidget(_app(inspector));
    await tester.tap(find.byKey(const Key('inspect-button')));
    await tester.pumpAndSettle();
    expect(inspector.lastPath, isNull);
  });

  test('core errors become readable messages', () {
    expect(
      describeCoreError(const CoreError.notARepository(path: '/tmp')),
      'Not a Git repository: /tmp',
    );
    expect(
      describeCoreError(const CoreError.pathNotFound(path: '/nope')),
      'Folder not found: /nope',
    );
  });
}
