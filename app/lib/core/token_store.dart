import 'dart:io';

import 'package:clotho_keystore/clotho_keystore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the GitHub token lives between launches.
abstract interface class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> delete();
}

/// The OS keychain: Keychain on macOS, Credential Manager on Windows,
/// libsecret on Linux and the Android Keystore.
class SecureTokenStore implements TokenStore {
  const SecureTokenStore();

  static const _key = 'github_token';
  static const _storage = FlutterSecureStorage(
    // The app is distributed unsigned-by-Apple, so use the login keychain
    // rather than the data-protection keychain (which needs an entitlement).
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
    // The plugin's default wipes ALL saved data whenever one read fails on
    // Android. A passing hiccup (for example the background fetch reading
    // at the same moment as the app) then silently signed people out. Keep
    // the data and let the caller retry instead.
    aOptions: AndroidOptions(resetOnError: false),
  );

  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);
  @override
  Future<void> delete() => _storage.delete(key: _key);
}

/// Android: an app-private file encrypted with an Android Keystore key.
///
/// The keychain plugin used before lost the saved token after some restarts,
/// signing people out daily. This store never deletes on a failed read, and
/// moves a token saved by the old store over the first time it is read.
class AndroidKeystoreTokenStore implements TokenStore {
  const AndroidKeystoreTokenStore({
    this.keystore = const ClothoKeystore(),
    this.legacy = const SecureTokenStore(),
  });

  static const _key = 'github_token';
  final ClothoKeystore keystore;
  final TokenStore legacy;

  @override
  Future<String?> read() async {
    final saved = await keystore.read(_key);
    if (saved != null) return saved;
    String? old;
    try {
      old = await legacy.read();
    } catch (_) {
      return null;
    }
    if (old == null) return null;
    await keystore.write(_key, old);
    try {
      await legacy.delete();
    } catch (_) {}
    return old;
  }

  @override
  Future<void> write(String token) => keystore.write(_key, token);

  @override
  Future<void> delete() async {
    await keystore.delete(_key);
    try {
      await legacy.delete();
    } catch (_) {}
  }
}

/// The token store for this platform.
TokenStore platformTokenStore() => Platform.isAndroid
    ? const AndroidKeystoreTokenStore()
    : const SecureTokenStore();

/// Keeps the token in memory only (tests, or when no keychain is available).
class MemoryTokenStore implements TokenStore {
  MemoryTokenStore([this._token]);
  String? _token;

  @override
  Future<String?> read() async => _token;
  @override
  Future<void> write(String token) async => _token = token;
  @override
  Future<void> delete() async => _token = null;
}
