import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/errors.dart';
import '../core/git_service.dart' show AuthOptions;
import '../core/github_service.dart';
import '../core/token_store.dart';
import '../src/rust/error.dart';

/// A device-flow sign-in waiting for the person to approve it on GitHub.
class PendingSignIn {
  const PendingSignIn(this.code, this.expiresAt);
  final DeviceCode code;
  final DateTime expiresAt;
}

/// Owns the GitHub token and the signed-in user.
class AuthController extends ChangeNotifier {
  AuthController({
    required this.github,
    required this.store,
    this.clientId = githubClientId,
    this.retryDelay = const Duration(milliseconds: 300),
  });

  /// Base wait between attempts to read the saved token.
  final Duration retryDelay;

  final GitHubService github;
  final TokenStore store;
  final String clientId;

  String? _token;
  GitHubUser? _user;
  bool _loading = true;
  PendingSignIn? _pending;
  String? _signInError;
  String? _storageWarning;
  Timer? _poll;
  int _interval = 5;

  bool get loading => _loading;
  bool get signedIn => _token != null;
  String? get token => _token;
  GitHubUser? get user => _user;
  PendingSignIn? get pending => _pending;

  /// Why the last browser sign-in ended without a token, if it did.
  String? get signInError => _signInError;

  /// Set when the OS keychain could not store the token, so it lasts only
  /// until the app closes.
  String? get storageWarning => _storageWarning;

  /// Whether this build can sign in through the browser (device flow).
  bool get deviceFlowAvailable => clientId.isNotEmpty;

  AuthOptions get authOptions => AuthOptions(token: _token);

  Future<void> init() async {
    _token = await _readSaved();
    _loading = false;
    notifyListeners();
    if (_token != null) await refreshUser();
  }

  /// Reads the saved token, retrying a failed read a few times: a keychain
  /// that is busy or still unlocking should not look like being signed out.
  /// A read that keeps failing leaves the saved token alone.
  Future<String?> _readSaved() async {
    Object? last;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        return await store.read();
      } catch (e) {
        last = e;
        await Future<void>.delayed(retryDelay * (attempt + 1));
      }
    }
    _storageWarning =
        'Your saved GitHub sign-in could not be read right now ($last). '
        'Restart the app to try again before signing in.';
    return null;
  }

  /// Re-reads the profile. A rejected token signs out; a network failure
  /// keeps the token so the person stays signed in offline.
  Future<void> refreshUser() async {
    final t = _token;
    if (t == null) return;
    try {
      _user = await github.user(t);
    } on CoreError_Auth {
      await signOut();
      _signInError =
          'GitHub no longer accepts your saved sign-in (it may have been '
          'revoked). Sign in again.';
      notifyListeners();
      return;
    } catch (_) {
      // Offline or GitHub unavailable; try again later.
    }
    notifyListeners();
  }

  /// Validates and saves a personal access token.
  Future<GitHubUser> signInWithToken(String token) async {
    final t = token.trim();
    if (t.isEmpty) {
      throw const CoreError.invalidInput(message: 'paste a token first');
    }
    final user = await github.user(t);
    await _save(t, user);
    return user;
  }

  /// Starts browser sign-in. Show [PendingSignIn.code] to the person; the
  /// controller polls GitHub and signs in once they approve.
  Future<DeviceCode> startDeviceSignIn() async {
    cancelDeviceSignIn();
    _signInError = null;
    final code = await github.startDeviceFlow();
    _interval = code.interval < 1 ? 5 : code.interval;
    _pending = PendingSignIn(
      code,
      DateTime.now().add(Duration(seconds: code.expiresIn)),
    );
    notifyListeners();
    _schedulePoll();
    return code;
  }

  void cancelDeviceSignIn() {
    _poll?.cancel();
    _poll = null;
    if (_pending != null) {
      _pending = null;
      notifyListeners();
    }
  }

  void _schedulePoll() {
    _poll?.cancel();
    _poll = Timer(Duration(seconds: _interval), _pollOnce);
  }

  Future<void> _pollOnce() async {
    final p = _pending;
    if (p == null) return;
    if (DateTime.now().isAfter(p.expiresAt)) {
      _finishPending('The code expired. Start again.');
      return;
    }
    try {
      final r = await github.pollDeviceFlow(p.code.deviceCode);
      if (!identical(_pending, p)) return; // cancelled meanwhile
      switch (r) {
        case DevicePoll_Pending():
          _schedulePoll();
        case DevicePoll_SlowDown(:final interval):
          _interval = interval;
          _schedulePoll();
        case DevicePoll_Authorized(:final token):
          final user = await github.user(token);
          _pending = null;
          await _save(token, user);
        case DevicePoll_Expired():
          _finishPending('The code expired. Start again.');
        case DevicePoll_Denied():
          _finishPending('Sign-in was cancelled on GitHub.');
      }
    } on CoreError_Network {
      // Temporary network trouble; keep polling until the code expires.
      if (identical(_pending, p)) _schedulePoll();
    } catch (e) {
      if (identical(_pending, p)) _finishPending(describeError(e));
    }
  }

  void _finishPending(String error) {
    _pending = null;
    _signInError = error;
    notifyListeners();
  }

  Future<void> _save(String token, GitHubUser user) async {
    _token = token;
    _user = user;
    _storageWarning = null;
    try {
      await store.write(token);
    } catch (e) {
      _storageWarning =
          'Your system keychain is not available, so you will need to sign in '
          'again next time ($e).';
    }
    notifyListeners();
  }

  Future<void> signOut() async {
    cancelDeviceSignIn();
    _token = null;
    _user = null;
    try {
      await store.delete();
    } catch (_) {}
    notifyListeners();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }
}
