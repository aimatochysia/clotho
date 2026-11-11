import 'dart:async';

import 'package:clotho/core/update_service.dart';
import 'package:clotho/src/rust/error.dart';

UpdateInfo updateInfo({String version = '0.2.0', bool withAsset = true}) =>
    UpdateInfo(
      version: version,
      tag: 'v$version',
      name: 'Clotho $version',
      notes: '## Features\n- shiny',
      htmlUrl: 'https://github.com/aimatochysia/clotho/releases/tag/v$version',
      asset: withAsset
          ? ReleaseAsset(
              name: 'clotho-$version-linux-amd64.deb',
              url: 'https://example.invalid/pkg',
              size: BigInt.from(1000),
            )
          : null,
      sumsUrl: 'https://example.invalid/sums',
      signatureUrl: 'https://example.invalid/sig',
    );

class FakeUpdateService implements UpdateService {
  FakeUpdateService({this.package = PackageKind.deb});

  final PackageKind package;
  UpdateInfo? next;
  Object? checkError;
  Object? downloadError;
  final installed = <String>[];

  @override
  PlatformInfo get platform =>
      PlatformInfo(os: 'linux', arch: 'x86_64', package: package);

  @override
  Future<UpdateInfo?> check(String currentVersion) async {
    if (checkError != null) throw checkError!;
    return next;
  }

  @override
  Stream<DownloadProgress> download(UpdateInfo update) async* {
    yield DownloadProgress.downloading(
      received: BigInt.from(500),
      total: BigInt.from(1000),
    );
    if (downloadError != null) throw downloadError!;
    yield const DownloadProgress.verifying();
    yield DownloadProgress.done(
      path: '/tmp/${update.asset!.name}',
      sha256: 'ab' * 32,
    );
  }

  @override
  Future<InstallResult> install(String path) async {
    installed.add(path);
    return package == PackageKind.deb
        ? InstallResult.manual
        : InstallResult.started;
  }

  @override
  Future<void> reveal(String path) async {}
}

const integrityError = CoreError.integrity(message: 'SHA-256 mismatch');
