import 'package:clotho/core/update_service.dart';
import 'package:clotho/src/rust/error.dart';
import 'package:clotho/state/update_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_update.dart';

void main() {
  test('finds an update, downloads and verifies it', () async {
    final svc = FakeUpdateService()..next = updateInfo();
    final c = UpdateController(service: svc, currentVersion: '0.1.0');
    final phases = <UpdatePhase>[];
    c.addListener(() => phases.add(c.phase));
    expect(await c.check(), isNotNull);
    expect(c.showBanner, isTrue);
    await c.download();
    expect(c.phase, UpdatePhase.ready);
    expect(c.path, '/tmp/clotho-0.2.0-linux-amd64.deb');
    expect(
      phases,
      containsAllInOrder([
        UpdatePhase.checking,
        UpdatePhase.downloading,
        UpdatePhase.verifying,
        UpdatePhase.ready,
      ]),
    );
    expect(await c.install(), InstallResult.manual);
    expect(svc.installed, [c.path]);
  });

  test('up to date shows no banner', () async {
    final c = UpdateController(
      service: FakeUpdateService(),
      currentVersion: '0.2.0',
    );
    expect(await c.check(), isNull);
    expect(c.showBanner, isFalse);
    expect(c.lastChecked, isNotNull);
  });

  test('silent check swallows errors, manual check reports them', () async {
    final svc = FakeUpdateService()
      ..checkError = const CoreError.network(message: 'offline');
    final c = UpdateController(service: svc, currentVersion: '0.1.0');
    await c.check(silent: true);
    expect(c.phase, UpdatePhase.idle);
    expect(c.error, isNull);
    await expectLater(c.check(), throwsA(isA<CoreError_Network>()));
    expect(c.phase, UpdatePhase.failed);
    expect(c.error, contains('Could not reach'));
  });

  test('a failed verification leaves nothing to install', () async {
    final svc = FakeUpdateService()
      ..next = updateInfo()
      ..downloadError = integrityError;
    final c = UpdateController(service: svc, currentVersion: '0.1.0');
    await c.check();
    await c.download();
    expect(c.phase, UpdatePhase.failed);
    expect(c.path, isNull);
    expect(c.error, contains('Update rejected'));
    expect(await c.install(), InstallResult.manual);
    expect(svc.installed, isEmpty);
  });

  test('dismiss hides the banner until a newer version appears', () async {
    final svc = FakeUpdateService()..next = updateInfo();
    final c = UpdateController(service: svc, currentVersion: '0.1.0');
    await c.check();
    c.dismiss();
    expect(c.showBanner, isFalse);
    await c.check();
    expect(c.showBanner, isFalse);
    svc.next = updateInfo(version: '0.3.0');
    await c.check();
    expect(c.showBanner, isTrue);
  });

  test('release without a package for this platform cannot download', () async {
    final svc = FakeUpdateService()..next = updateInfo(withAsset: false);
    final c = UpdateController(service: svc, currentVersion: '0.1.0');
    await c.check();
    expect(c.canDownload, isFalse);
    await c.download();
    expect(c.phase, UpdatePhase.idle);
  });
}
