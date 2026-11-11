import 'package:flutter/material.dart';

import 'home/home_page.dart';
import 'home/repo_inspector.dart';

class ClothoApp extends StatelessWidget {
  const ClothoApp({
    super.key,
    required this.coreVersion,
    required this.libgit2Version,
    required this.inspector,
  });

  final String coreVersion;
  final String libgit2Version;
  final RepoInspector inspector;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF6750A4);
    return MaterialApp(
      title: 'Clotho',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: seed, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: seed,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: HomePage(
        coreVersion: coreVersion,
        libgit2Version: libgit2Version,
        inspector: inspector,
      ),
    );
  }
}
