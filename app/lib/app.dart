import 'package:flutter/material.dart';

import 'core/github_service.dart';
import 'state/app_controller.dart';
import 'state/auth_controller.dart';
import 'state/github_scope.dart';
import 'ui/dashboard_page.dart';

class ClothoApp extends StatelessWidget {
  const ClothoApp({
    super.key,
    required this.app,
    required this.auth,
    required this.github,
  });

  final AppController app;
  final AuthController auth;
  final GitHubService github;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF6750A4);
    return GitHubScope(
      auth: auth,
      github: github,
      child: MaterialApp(
        title: 'Clotho',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: seed, useMaterial3: true),
        darkTheme: ThemeData(
          colorSchemeSeed: seed,
          brightness: Brightness.dark,
          useMaterial3: true,
        ),
        home: DashboardPage(app: app),
      ),
    );
  }
}
