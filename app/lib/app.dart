import 'package:flutter/material.dart';

import 'core/github_service.dart';
import 'state/app_controller.dart';
import 'state/auth_controller.dart';
import 'state/github_scope.dart';
import 'state/update_controller.dart';
import 'state/update_scope.dart';
import 'ui/dashboard_page.dart';
import 'ui/theme.dart';

class ClothoApp extends StatelessWidget {
  const ClothoApp({
    super.key,
    required this.app,
    required this.auth,
    required this.github,
    this.updates,
  });

  final AppController app;
  final AuthController auth;
  final GitHubService github;
  final UpdateController? updates;

  @override
  Widget build(BuildContext context) {
    final u = updates;
    final Widget root = GitHubScope(
      auth: auth,
      github: github,
      child: MaterialApp(
        title: 'Clotho',
        debugShowCheckedModeBanner: false,
        theme: ClothoTheme.light,
        darkTheme: ClothoTheme.dark,
        home: DashboardPage(app: app),
      ),
    );
    return u == null ? root : UpdateScope(updates: u, child: root);
  }
}
