import 'dart:io';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:workmanager/workmanager.dart';

import '../src/rust/frb_generated.dart';
import 'auto_fetch.dart';
import 'git_service.dart';
import 'notifications.dart';
import 'token_store.dart';

/// Keeps scheduled fetches running while the app is closed. Only Android
/// supports this; on desktop, fetches run while the app is open.
abstract interface class BackgroundFetch {
  bool get supported;

  /// Whether the OS lets the app run in the background reliably (on
  /// Android: battery optimisation is off for Clotho).
  Future<bool> allowed();

  /// Asks the person to allow background work. Returns the new state.
  Future<bool> requestAllowed();

  /// Schedules the background task when [enabled], cancels it otherwise.
  Future<void> sync({required bool enabled});
}

class NoBackgroundFetch implements BackgroundFetch {
  const NoBackgroundFetch();
  @override
  bool get supported => false;
  @override
  Future<bool> allowed() async => false;
  @override
  Future<bool> requestAllowed() async => false;
  @override
  Future<void> sync({required bool enabled}) async {}
}

const _taskName = 'clotho-auto-fetch';
const _storage = MethodChannel('clotho/storage');

/// Android WorkManager. Android runs periodic work at most every 15 minutes,
/// so shorter schedules are caught up on the next run.
class AndroidBackgroundFetch implements BackgroundFetch {
  AndroidBackgroundFetch();

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    await Workmanager().initialize(backgroundFetchDispatcher);
    _initialized = true;
  }

  @override
  bool get supported => true;

  @override
  Future<bool> allowed() async {
    try {
      return await _storage.invokeMethod<bool>(
            'isIgnoringBatteryOptimizations',
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestAllowed() async {
    try {
      return await _storage.invokeMethod<bool>(
            'requestIgnoreBatteryOptimizations',
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> sync({required bool enabled}) async {
    try {
      await initialize();
      if (enabled && await allowed()) {
        await Workmanager().registerPeriodicTask(
          _taskName,
          _taskName,
          frequency: const Duration(minutes: 15),
          constraints: Constraints(networkType: NetworkType.connected),
          existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        );
      } else {
        await Workmanager().cancelByUniqueName(_taskName);
      }
    } catch (_) {
      // Background scheduling is best effort; in-app fetches still run.
    }
  }
}

BackgroundFetch platformBackgroundFetch() =>
    Platform.isAndroid ? AndroidBackgroundFetch() : const NoBackgroundFetch();

/// Runs in a separate isolate started by WorkManager, with no UI.
@pragma('vm:entry-point')
void backgroundFetchDispatcher() {
  Workmanager().executeTask((task, _) async {
    DartPluginRegistrant.ensureInitialized();
    try {
      await RustLib.init();
    } catch (_) {
      // Already loaded in this process.
    }
    final configDir = await getApplicationSupportDirectory();
    String? token;
    try {
      token = await const SecureTokenStore().read();
    } catch (_) {}
    final git = RustGitService(
      configDir: configDir.path,
      authProvider: () async => AuthOptions(token: token),
    );
    final results = await runDueFetches(git);
    await LocalFetchNotifier().newCommits([
      for (final r in results)
        if (r.newCommits != null) r.newCommits!,
    ]);
    return true;
  });
}
