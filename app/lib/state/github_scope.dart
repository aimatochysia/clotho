import 'package:flutter/widgets.dart';

import '../core/github_service.dart';
import 'auth_controller.dart';

/// Makes the GitHub service and sign-in state available below the app root.
class GitHubScope extends InheritedWidget {
  const GitHubScope({
    super.key,
    required this.auth,
    required this.github,
    required super.child,
  });

  final AuthController auth;
  final GitHubService github;

  static GitHubScope of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<GitHubScope>();
    assert(scope != null, 'GitHubScope missing above this widget');
    return scope!;
  }

  @override
  bool updateShouldNotify(GitHubScope oldWidget) =>
      auth != oldWidget.auth || github != oldWidget.github;
}
