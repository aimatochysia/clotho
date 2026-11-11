import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'core/git_service.dart';
import 'src/rust/frb_generated.dart';
import 'state/app_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  final configDir = await getApplicationSupportDirectory();
  final app = AppController(RustGitService(configDir: configDir.path));
  runApp(ClothoApp(app: app));
  await app.init();
}
