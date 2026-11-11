import '../src/rust/api/github.dart' as gh;
import '../src/rust/api/remote.dart' show AuthOptions;

import '../src/rust/api/github.dart'
    show
        CloneProgress,
        DeviceCode,
        DevicePoll,
        GitHubIssue,
        GitHubPull,
        GitHubRemote,
        GitHubRepo,
        GitHubUser,
        WorkflowRun;

export '../src/rust/api/github.dart'
    show
        CloneProgress,
        CloneProgress_CheckingOut,
        CloneProgress_Done,
        CloneProgress_Receiving,
        CloneProgress_Resolving,
        DeviceCode,
        DevicePoll,
        DevicePoll_Authorized,
        DevicePoll_Denied,
        DevicePoll_Expired,
        DevicePoll_Pending,
        DevicePoll_SlowDown,
        GitHubIssue,
        GitHubPull,
        GitHubRemote,
        GitHubRepo,
        GitHubUser,
        WorkflowRun;

/// OAuth App client id, baked in at build time with
/// `--dart-define=CLOTHO_GITHUB_CLIENT_ID=...`. Empty means device-flow
/// sign-in is unavailable and only personal access tokens work.
const githubClientId = String.fromEnvironment('CLOTHO_GITHUB_CLIENT_ID');

/// Scopes requested at sign-in: private repos, profile, and workflow files.
const githubScopes = 'repo read:user workflow';

/// GitHub calls the UI makes. Tests replace it with a fake.
abstract interface class GitHubService {
  Future<DeviceCode> startDeviceFlow();
  Future<DevicePoll> pollDeviceFlow(String deviceCode);
  Future<GitHubUser> user(String token);
  Future<List<GitHubRepo>> repos(String token);
  Future<List<GitHubPull>> pulls(
    String? token,
    String owner,
    String repo, {
    String state = 'open',
  });
  Future<List<GitHubIssue>> issues(
    String? token,
    String owner,
    String repo, {
    String state = 'open',
  });
  Future<List<WorkflowRun>> runs(String? token, String owner, String repo);
  Future<GitHubRemote?> remoteOf(String path);

  /// Clones [url] into [dest]; the stream ends with [CloneProgress_Done].
  Stream<CloneProgress> clone(String url, String dest, String? token);
}

class RustGitHubService implements GitHubService {
  const RustGitHubService({this.clientId = githubClientId});

  final String clientId;

  @override
  Future<DeviceCode> startDeviceFlow() =>
      gh.githubStartDeviceFlow(clientId: clientId, scopes: githubScopes);
  @override
  Future<DevicePoll> pollDeviceFlow(String deviceCode) =>
      gh.githubPollDeviceFlow(clientId: clientId, deviceCode: deviceCode);
  @override
  Future<GitHubUser> user(String token) => gh.githubGetUser(token: token);
  @override
  Future<List<GitHubRepo>> repos(String token) =>
      gh.githubListRepos(token: token);
  @override
  Future<List<GitHubPull>> pulls(
    String? token,
    String owner,
    String repo, {
    String state = 'open',
  }) =>
      gh.githubListPulls(token: token, owner: owner, repo: repo, state: state);
  @override
  Future<List<GitHubIssue>> issues(
    String? token,
    String owner,
    String repo, {
    String state = 'open',
  }) =>
      gh.githubListIssues(token: token, owner: owner, repo: repo, state: state);
  @override
  Future<List<WorkflowRun>> runs(String? token, String owner, String repo) =>
      gh.githubListRuns(token: token, owner: owner, repo: repo);
  @override
  Future<GitHubRemote?> remoteOf(String path) => gh.githubRemoteOf(path: path);
  @override
  Stream<CloneProgress> clone(String url, String dest, String? token) =>
      gh.cloneRepo(
        url: url,
        dest: dest,
        auth: AuthOptions(token: token),
      );
}
