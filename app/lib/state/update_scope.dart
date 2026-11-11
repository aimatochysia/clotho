import 'package:flutter/widgets.dart';

import 'update_controller.dart';

/// Makes the updater available to the dashboard and settings.
class UpdateScope extends InheritedWidget {
  const UpdateScope({super.key, required this.updates, required super.child});

  final UpdateController updates;

  /// Null in tests and builds that run without the updater.
  static UpdateController? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<UpdateScope>()?.updates;

  @override
  bool updateShouldNotify(UpdateScope oldWidget) =>
      updates != oldWidget.updates;
}
