import 'package:clotho/core/token_store.dart';
import 'package:clotho_keystore/clotho_keystore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _BrokenLegacy implements TokenStore {
  @override
  Future<String?> read() async => throw StateError('boom');
  @override
  Future<void> write(String token) async {}
  @override
  Future<void> delete() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, String> files;
  late bool failReads;

  setUp(() {
    files = {};
    failReads = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ClothoKeystore.channel, (call) async {
          final args = (call.arguments as Map).cast<String, Object?>();
          final key = args['key']! as String;
          switch (call.method) {
            case 'read':
              if (failReads) {
                throw PlatformException(code: 'keystore', message: 'busy');
              }
              return files[key];
            case 'write':
              files[key] = args['value']! as String;
              return null;
            case 'delete':
              files.remove(key);
              return null;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ClothoKeystore.channel, null);
  });

  test('writes, reads back and deletes', () async {
    final store = AndroidKeystoreTokenStore(legacy: MemoryTokenStore());
    expect(await store.read(), isNull);
    await store.write('gho_abc');
    expect(files['github_token'], 'gho_abc');
    expect(await store.read(), 'gho_abc');
    await store.delete();
    expect(await store.read(), isNull);
  });

  test('moves a token from the old store once', () async {
    final legacy = MemoryTokenStore('gho_old');
    final store = AndroidKeystoreTokenStore(legacy: legacy);
    expect(await store.read(), 'gho_old');
    expect(files['github_token'], 'gho_old');
    expect(await legacy.read(), isNull);
    expect(await store.read(), 'gho_old');
  });

  test('a failing old store reads as signed out without throwing', () async {
    final store = AndroidKeystoreTokenStore(legacy: _BrokenLegacy());
    expect(await store.read(), isNull);
  });

  test('a failed read throws and keeps the saved token', () async {
    files['github_token'] = 'gho_keep';
    final store = AndroidKeystoreTokenStore(legacy: MemoryTokenStore());
    failReads = true;
    await expectLater(store.read(), throwsA(isA<PlatformException>()));
    expect(files['github_token'], 'gho_keep');
    failReads = false;
    expect(await store.read(), 'gho_keep');
  });

  test('sign out clears both stores', () async {
    final legacy = MemoryTokenStore('gho_old');
    final store = AndroidKeystoreTokenStore(legacy: legacy);
    await store.write('gho_new');
    await store.delete();
    expect(files, isEmpty);
    expect(await legacy.read(), isNull);
  });
}
