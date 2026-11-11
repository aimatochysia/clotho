import 'package:clotho/app.dart';
import 'package:clotho/home/repo_inspector.dart';
import 'package:clotho/src/rust/api/app.dart' as core;
import 'package:clotho/src/rust/frb_generated.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());

  testWidgets('calls the Rust core', (tester) async {
    await tester.pumpWidget(
      ClothoApp(
        coreVersion: core.coreVersion(),
        libgit2Version: core.libgit2Version(),
        inspector: const RustRepoInspector(),
      ),
    );
    expect(find.textContaining('libgit2 1.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('path-field')),
      '/definitely/not/here',
    );
    await tester.tap(find.byKey(const Key('inspect-button')));
    await tester.pumpAndSettle();
    expect(find.text('Folder not found: /definitely/not/here'), findsOneWidget);
  });
}
