import 'package:clotho/core/github_service.dart';
import 'package:clotho/core/token_store.dart';
import 'package:clotho/state/auth_controller.dart';
import 'package:clotho/src/rust/error.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_github.dart';

class FailingStore implements TokenStore {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String token) async => throw Exception('no keyring');
  @override
  Future<void> delete() async {}
}

void main() {
  test('restores a saved token and loads the user', () async {
    final gh = FakeGitHubService();
    final auth = fakeAuth(gh, token: 'good');
    await auth.init();
    expect(auth.signedIn, isTrue);
    expect(auth.user?.login, 'octo');
    expect(auth.authOptions.token, 'good');
  });

  test('a rejected saved token signs out', () async {
    final store = MemoryTokenStore('revoked');
    final auth = AuthController(
      github: FakeGitHubService(),
      store: store,
      clientId: 'x',
    );
    await auth.init();
    expect(auth.signedIn, isFalse);
    expect(await store.read(), isNull);
  });

  test('personal access token is validated before saving', () async {
    final store = MemoryTokenStore();
    final auth = AuthController(
      github: FakeGitHubService(),
      store: store,
      clientId: '',
    );
    await auth.init();
    expect(auth.deviceFlowAvailable, isFalse);
    await expectLater(
      auth.signInWithToken('nope'),
      throwsA(isA<CoreError_Auth>()),
    );
    expect(auth.signedIn, isFalse);
    await auth.signInWithToken('  good \n');
    expect(await store.read(), 'good');
  });

  test('keychain failure keeps the token for this session', () async {
    final auth = AuthController(
      github: FakeGitHubService(),
      store: FailingStore(),
    );
    await auth.init();
    await auth.signInWithToken('good');
    expect(auth.signedIn, isTrue);
    expect(auth.storageWarning, contains('keychain'));
  });

  test('device flow polls, honours slow_down and signs in', () {
    fakeAsync((async) {
      final gh = FakeGitHubService()
        ..validTokens.add('gho_new')
        ..polls.addAll(const [
          DevicePoll.pending(),
          DevicePoll.slowDown(interval: 10),
          DevicePoll.authorized(token: 'gho_new', scopes: 'repo'),
        ]);
      final auth = fakeAuth(gh);
      auth.init();
      async.flushMicrotasks();
      auth.startDeviceSignIn();
      async.flushMicrotasks();
      expect(auth.pending?.code.userCode, 'ABCD-1234');
      async.elapse(const Duration(seconds: 5));
      expect(gh.pollCount, 1);
      async.elapse(const Duration(seconds: 5));
      expect(gh.pollCount, 2);
      // After slow_down the next poll waits 10 s.
      async.elapse(const Duration(seconds: 9));
      expect(gh.pollCount, 2);
      async.elapse(const Duration(seconds: 1));
      expect(gh.pollCount, 3);
      expect(auth.signedIn, isTrue);
      expect(auth.pending, isNull);
      expect(auth.token, 'gho_new');
    });
  });

  test('denied device flow reports why', () {
    fakeAsync((async) {
      final gh = FakeGitHubService()..polls.add(const DevicePoll.denied());
      final auth = fakeAuth(gh);
      auth.startDeviceSignIn();
      async.elapse(const Duration(seconds: 5));
      expect(auth.signedIn, isFalse);
      expect(auth.pending, isNull);
      expect(auth.signInError, contains('cancelled'));
    });
  });

  test('cancel stops polling', () {
    fakeAsync((async) {
      final gh = FakeGitHubService();
      final auth = fakeAuth(gh);
      auth.startDeviceSignIn();
      async.flushMicrotasks();
      auth.cancelDeviceSignIn();
      async.elapse(const Duration(seconds: 30));
      expect(gh.pollCount, 0);
    });
  });
}
