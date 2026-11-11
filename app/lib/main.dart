import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'core/git_service.dart';
import 'core/github_service.dart';
import 'core/token_store.dart';
import 'src/rust/frb_generated.dart';
import 'state/app_controller.dart';
import 'state/auth_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  final configDir = await getApplicationSupportDirectory();
  const github = RustGitHubService();
  final auth = AuthController(github: github, store: const SecureTokenStore());
  final app = AppController(
    RustGitService(
      configDir: configDir.path,
      authProvider: () async => auth.authOptions,
    ),
  );
  runApp(ClothoApp(app: app, auth: auth, github: github));
  await auth.init();
  await app.init();
}
