import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/errors.dart';
import '../core/update_service.dart';

enum UpdatePhase { idle, checking, downloading, verifying, ready, failed }

/// Finds, downloads and installs new Clotho releases.
class UpdateController extends ChangeNotifier {
  UpdateController({required this.service, required this.currentVersion});

  final UpdateService service;
  final String currentVersion;

  UpdatePhase _phase = UpdatePhase.idle;
  UpdateInfo? _available;
  String? _error;
  double? _progress;
  String? _path;
  String? _sha256;
  bool _dismissed = false;
  DateTime? _lastChecked;
  StreamSubscription<DownloadProgress>? _sub;

  UpdatePhase get phase => _phase;
  UpdateInfo? get available => _available;
  String? get error => _error;

  /// Download progress from 0 to 1, or null when the size is unknown.
  double? get progress => _progress;

  /// The verified package on disk once [phase] is [UpdatePhase.ready].
  String? get path => _path;
  String? get sha256 => _sha256;
  DateTime? get lastChecked => _lastChecked;

  /// Whether the dashboard should show the "update available" banner.
  bool get showBanner => _available != null && !_dismissed;

  /// True when the release has a package for this platform.
  bool get canDownload => _available?.asset != null;

  PackageKind get package => service.platform.package;

  /// Looks for a newer release. With [silent], failures are not reported
  /// (used for the automatic check on start).
  Future<UpdateInfo?> check({bool silent = false}) async {
    if (_phase == UpdatePhase.checking ||
        _phase == UpdatePhase.downloading ||
        _phase == UpdatePhase.verifying) {
      return _available;
    }
    _phase = UpdatePhase.checking;
    _error = null;
    notifyListeners();
    try {
      final found = await service.check(currentVersion);
      if (found?.version != _available?.version) {
        _path = null;
        _dismissed = false;
      }
      _available = found;
      _phase = _path != null ? UpdatePhase.ready : UpdatePhase.idle;
      _lastChecked = DateTime.now();
    } catch (e) {
      _phase = silent ? UpdatePhase.idle : UpdatePhase.failed;
      _error = silent ? null : describeError(e);
      if (!silent) {
        notifyListeners();
        rethrow;
      }
    }
    notifyListeners();
    return _available;
  }

  void dismiss() {
    _dismissed = true;
    notifyListeners();
  }

  /// Downloads and verifies the update. Completes when it is ready or failed.
  Future<void> download() {
    final u = _available;
    if (u == null || !canDownload) return Future.value();
    _sub?.cancel();
    _phase = UpdatePhase.downloading;
    _progress = null;
    _error = null;
    notifyListeners();
    final done = Completer<void>();
    _sub = service
        .download(u)
        .listen(
          (p) {
            switch (p) {
              case DownloadProgress_Downloading(:final received, :final total):
                _progress = total == BigInt.zero
                    ? null
                    : (received.toDouble() / total.toDouble()).clamp(0, 1);
              case DownloadProgress_Verifying():
                _phase = UpdatePhase.verifying;
              case DownloadProgress_Done(:final path, :final sha256):
                _phase = UpdatePhase.ready;
                _path = path;
                _sha256 = sha256;
                _progress = 1;
            }
            notifyListeners();
          },
          onError: (Object e) {
            _phase = UpdatePhase.failed;
            _error = describeError(e);
            notifyListeners();
            if (!done.isCompleted) done.complete();
          },
          onDone: () {
            if (!done.isCompleted) done.complete();
          },
        );
    return done.future;
  }

  Future<InstallResult> install() async {
    final p = _path;
    if (p == null) return InstallResult.manual;
    return service.install(p);
  }

  Future<void> reveal() async {
    final p = _path;
    if (p != null) await service.reveal(p);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
