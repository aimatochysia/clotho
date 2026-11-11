import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'auto_fetch.dart';

/// Tells the person about new commits found by an automatic fetch.
abstract interface class FetchNotifier {
  /// Asks the OS for permission to show notifications. Returns whether they
  /// are allowed.
  Future<bool> requestPermission();
  Future<void> newCommits(List<NewCommits> found);
}

/// Does nothing (tests, or a platform without notifications).
class SilentNotifier implements FetchNotifier {
  const SilentNotifier();
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> newCommits(List<NewCommits> found) async {}
}

/// System notifications through flutter_local_notifications.
class LocalFetchNotifier implements FetchNotifier {
  LocalFetchNotifier();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _channel = AndroidNotificationDetails(
    'auto_fetch',
    'New commits',
    channelDescription: 'New commits found by automatic fetch',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  Future<void> _init() async {
    if (_ready) return;
    _ready =
        await _plugin.initialize(
          settings: const InitializationSettings(
            android: AndroidInitializationSettings(
              '@mipmap/ic_launcher_monochrome',
            ),
            macOS: DarwinInitializationSettings(
              requestAlertPermission: false,
              requestBadgePermission: false,
              requestSoundPermission: false,
            ),
            linux: LinuxInitializationSettings(defaultActionName: 'Open'),
            windows: WindowsInitializationSettings(
              appName: 'Clotho',
              appUserModelId: 'io.github.aimatochysia.clotho',
              guid: '6b0a0d3c-6f42-4b7e-9a51-2f6c8f1d9e3a',
            ),
          ),
        ) ??
        false;
  }

  @override
  Future<bool> requestPermission() async {
    try {
      await _init();
      if (Platform.isAndroid) {
        final android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        return await android?.requestNotificationsPermission() ?? true;
      }
      if (Platform.isMacOS) {
        final mac = _plugin
            .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin
            >();
        return await mac?.requestPermissions(alert: true, sound: true) ?? false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> newCommits(List<NewCommits> found) async {
    if (found.isEmpty) return;
    try {
      await _init();
      for (final n in found) {
        await _plugin.show(
          // One notification per repository; a newer one replaces it.
          id: n.path.hashCode & 0x7fffffff,
          title: n.title,
          body: n.body,
          notificationDetails: const NotificationDetails(android: _channel),
        );
      }
    } catch (_) {
      // Notifications are a nicety; never let them break a fetch.
    }
  }
}
