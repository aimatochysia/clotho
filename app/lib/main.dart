import 'package:flutter/material.dart';

import 'app.dart';
import 'home/repo_inspector.dart';
import 'src/rust/api/app.dart' as core;
import 'src/rust/frb_generated.dart';

Future<void> main() async {
  await RustLib.init();
  runApp(
    ClothoApp(
      coreVersion: core.coreVersion(),
      libgit2Version: core.libgit2Version(),
      inspector: const RustRepoInspector(),
    ),
  );
}
