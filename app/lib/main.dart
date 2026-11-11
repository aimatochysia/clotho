import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'core/git_service.dart';
import 'core/github_service.dart';
import 'core/token_store.dart';
import 'core/update_service.dart';
import 'src/rust/frb_generated.dart';
import 'state/app_controller.dart';
import 'state/auth_controller.dart';
import 'state/update_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  final configDir = await getApplicationSupportDirectory();
  final info = await PackageInfo.fromPlatform();
  const github = RustGitHubService();
  final auth = AuthController(github: github, store: const SecureTokenStore());
  final app = AppController(
    RustGitService(
      configDir: configDir.path,
      authProvider: () async => auth.authOptions,
    ),
  );
  final updates = UpdateController(
    service: RustUpdateService(),
    currentVersion: info.version,
  );
  runApp(ClothoApp(app: app, auth: auth, github: github, updates: updates));
  await auth.init();
  await app.init();
  if (app.settings.checkUpdates) {
    // Give startup a moment before going to the network.
    await Future<void>.delayed(const Duration(seconds: 3));
    await updates.check(silent: true);
  }
}
