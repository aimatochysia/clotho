import 'dart:async';

import 'package:clotho/core/github_service.dart';
import 'package:clotho/core/token_store.dart';
import 'package:clotho/src/rust/error.dart';
import 'package:clotho/state/auth_controller.dart';
import 'package:clotho/state/github_scope.dart';
import 'package:flutter/widgets.dart';

const octo = GitHubUser(
  login: 'octo',
  avatarUrl: 'https://example.invalid/a.png',
  htmlUrl: 'https://github.com/octo',
  scopes: ['repo'],
);

GitHubRepo ghRepo(String name, {bool archived = false}) => GitHubRepo(
  fullName: 'octo/$name',
  owner: 'octo',
  name: name,
  description: 'about $name',
  private: false,
  fork: false,
  archived: archived,
  cloneUrl: 'https://github.com/octo/$name.git',
  sshUrl: 'git@github.com:octo/$name.git',
  htmlUrl: 'https://github.com/octo/$name',
  defaultBranch: 'main',
  stars: 0,
);

class FakeGitHubService implements GitHubService {
  /// Tokens [user] accepts.
  final Set<String> validTokens = {'good'};

  /// Answers [pollDeviceFlow] returns, in order.
  final List<DevicePoll> polls = [];
  int pollCount = 0;
  List<GitHubRepo> repoList = [];
  List<GitHubPull> pullList = [];
  GitHubRemote? remote;

  @override
  Future<DeviceCode> startDeviceFlow() async => const DeviceCode(
    deviceCode: 'dc',
    userCode: 'ABCD-1234',
    verificationUri: 'https://github.com/login/device',
    expiresIn: 900,
    interval: 5,
  );

  @override
  Future<DevicePoll> pollDeviceFlow(String deviceCode) async {
    pollCount++;
    return polls.isEmpty ? const DevicePoll.pending() : polls.removeAt(0);
  }

  @override
  Future<GitHubUser> user(String token) async {
    if (!validTokens.contains(token)) {
      throw const CoreError.auth(message: 'bad token');
    }
    return octo;
  }

  @override
  Future<List<GitHubRepo>> repos(String token) async => repoList;
  @override
  Future<List<GitHubPull>> pulls(
    String? token,
    String owner,
    String repo, {
    String state = 'open',
  }) async => pullList;
  @override
  Future<List<GitHubIssue>> issues(
    String? token,
    String owner,
    String repo, {
    String state = 'open',
  }) async => const [];
  @override
  Future<List<WorkflowRun>> runs(
    String? token,
    String owner,
    String repo,
  ) async => const [];
  @override
  Future<GitHubRemote?> remoteOf(String path) async => remote;
  @override
  Stream<CloneProgress> clone(String url, String dest, String? token) =>
      Stream.fromIterable([CloneProgress.done(path: dest)]);
}

AuthController fakeAuth(FakeGitHubService gh, {String? token}) =>
    AuthController(
      github: gh,
      store: MemoryTokenStore(token),
      clientId: 'test-client',
    );

Widget scoped(Widget child, {FakeGitHubService? gh, AuthController? auth}) {
  final g = gh ?? FakeGitHubService();
  return GitHubScope(auth: auth ?? fakeAuth(g), github: g, child: child);
}
