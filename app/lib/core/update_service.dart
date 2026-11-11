import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../src/rust/api/update.dart' as ru;
import '../src/rust/api/update.dart'
    show DownloadProgress, PackageKind, PlatformInfo, UpdateInfo;

export '../src/rust/api/update.dart'
    show
        DownloadProgress,
        DownloadProgress_Done,
        DownloadProgress_Downloading,
        DownloadProgress_Verifying,
        PackageKind,
        PlatformInfo,
        ReleaseAsset,
        UpdateInfo;

/// What happened when the person pressed "Install".
enum InstallResult {
  /// The installer is running (Clotho may close).
  started,

  /// The person first has to allow it (Android "install unknown apps").
  needsPermission,

  /// Clotho cannot install this package itself; show the manual steps.
  manual,
}

/// Release lookup, verified download and platform installers.
abstract interface class UpdateService {
  PlatformInfo get platform;
  Future<UpdateInfo?> check(String currentVersion);
  Stream<DownloadProgress> download(UpdateInfo update);
  Future<InstallResult> install(String path);

  /// Shows the downloaded file in the system file manager.
  Future<void> reveal(String path);
}

class RustUpdateService implements UpdateService {
  RustUpdateService();

  @override
  late final PlatformInfo platform = ru.currentPlatform();

  static const _install = MethodChannel('clotho/install');

  @override
  Future<UpdateInfo?> check(String currentVersion) =>
      ru.checkForUpdate(currentVersion: currentVersion);

  @override
  Stream<DownloadProgress> download(UpdateInfo update) async* {
    final base = Platform.isAndroid
        // Must match res/xml/update_paths.xml.
        ? await getApplicationCacheDirectory()
        : (await getDownloadsDirectory()) ?? await getTemporaryDirectory();
    final dir = Platform.isAndroid
        ? '${base.path}/updates'
        : '${base.path}${Platform.pathSeparator}Clotho updates';
    yield* ru.downloadUpdate(update: update, destDir: dir);
  }

  @override
  Future<InstallResult> install(String path) async {
    switch (platform.package) {
      case PackageKind.apk:
        final r = await _install.invokeMethod<String>('installApk', {
          'path': path,
        });
        return r == 'permission'
            ? InstallResult.needsPermission
            : InstallResult.started;
      case PackageKind.windowsInstaller:
        await Process.start(path, const [], mode: ProcessStartMode.detached);
        return InstallResult.started;
      case PackageKind.dmg:
        await Process.run('open', [path]);
        return InstallResult.started;
      case PackageKind.deb:
      case PackageKind.arch:
      case PackageKind.tarball:
      case PackageKind.windowsZip:
      case PackageKind.unknown:
        return InstallResult.manual;
    }
  }

  @override
  Future<void> reveal(String path) async {
    if (Platform.isWindows) {
      await Process.start('explorer', ['/select,', path]);
    } else if (Platform.isMacOS) {
      await Process.run('open', ['-R', path]);
    } else if (Platform.isLinux) {
      await Process.start('xdg-open', [File(path).parent.path]);
    }
  }
}

/// The command a person runs to install a downloaded package by hand.
String manualInstallHint(PackageKind kind, String path) => switch (kind) {
  PackageKind.deb => 'sudo apt install "$path"',
  PackageKind.arch => 'sudo pacman -U "$path"',
  PackageKind.tarball =>
    'Extract it over your current Clotho folder: tar -xzf "$path" --strip-components=1 -C <your Clotho folder>',
  PackageKind.windowsZip =>
    'Close Clotho, then extract the zip over your current Clotho folder.',
  _ => 'Open the file to install it.',
};
