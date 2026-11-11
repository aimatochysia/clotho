import '../src/rust/error.dart';

/// Turns any error from the core into one sentence a person can act on.
String describeError(Object error) {
  if (error is CoreError) {
    return switch (error) {
      CoreError_NotARepository(:final path) => 'Not a Git repository: $path',
      CoreError_PathNotFound(:final path) => 'Folder not found: $path',
      CoreError_NothingToCommit() =>
        'Nothing to commit. Stage some changes first.',
      CoreError_MissingIdentity() =>
        'Set your name and email first: git config --global user.name "Your Name" '
            'and git config --global user.email you@example.com',
      CoreError_Conflicts(:final files) =>
        'Resolve the conflicts in ${files.length} file(s) first: ${files.take(3).join(', ')}'
            '${files.length > 3 ? '…' : ''}',
      CoreError_NotFastForward() =>
        'Your branch and the remote have diverged. Pull with merge or rebase, '
            'or change the pull setting.',
      CoreError_DirtyWorktree() => 'Your local changes would be overwritten. Commit or discard them first.',
      CoreError_BranchNotMerged(:final name) =>
        'Branch $name has commits that are not merged anywhere.',
      CoreError_NoUpstream(:final branch) =>
        'Branch $branch is not linked to a remote branch yet. Push it first.',
      CoreError_DetachedHead() =>
        'You are not on a branch. Check out a branch first.',
      CoreError_Auth(:final message) =>
        'Sign-in to the remote failed: $message',
      CoreError_PushRejected(:final message) => 'Push rejected: $message',
      CoreError_Network(:final message) =>
        'Could not reach the server. Check your connection. ($message)',
      CoreError_GitHub(:final status, :final message) => switch (status) {
        404 =>
          'GitHub could not find that, or your account has no access to it. '
              'Sign in to see private repositories.',
        _ => 'GitHub: ${_capitalize(message)}',
      },
      CoreError_Integrity(:final message) =>
        'Update rejected: $message. Nothing was installed.',
      CoreError_InvalidInput(:final message) => _capitalize(message),
      CoreError_Io(:final message) => _capitalize(message),
      CoreError_Git(:final message) => 'Git error: $message',
    };
  }
  return error.toString();
}

String _capitalize(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
