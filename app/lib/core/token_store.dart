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
