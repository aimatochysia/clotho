import 'package:flutter/material.dart';

import '../core/errors.dart';
import '../core/git_service.dart';
import '../state/repo_controller.dart';
import 'identity.dart';
import 'widgets/feedback.dart';

/// Asks how to undo the commit [oid] in plain words, then does it. Returns
/// true when something was undone.
///
/// The newest commit that is not on GitHub yet is taken back and its changes
/// return to Changes. Anything else gets a new commit that reverses it, so
/// shared history is never rewritten.
Future<bool> undoCommitFlow(
  BuildContext context,
  RepoController repo, {
  required String oid,
  required String summary,
}) async {
  final UndoPlan plan;
  try {
    plan = await repo.planUndo(oid);
  } catch (e) {
    if (context.mounted) showMessage(context, describeError(e), error: true);
    return false;
  }
  if (!context.mounted) return false;
  final name = '"$summary"';
  switch (plan.kind) {
    case UndoKind.unsupported:
      showMessage(
        context,
        plan.reason ?? 'This commit cannot be undone.',
        error: true,
      );
      return false;
    case UndoKind.takeBack:
      final ok = await confirm(
        context,
        title: 'Undo this commit?',
        message:
            '$name has not been pushed yet. It will be removed from the '
            'history, and its changes go back to Changes so you can edit '
            'them and commit again. Nothing is lost.\n\n'
            'Git: reset --soft',
        action: 'Undo commit',
      );
      if (!ok || !context.mounted) return false;
    case UndoKind.cancel:
      final where = plan.pushed
          ? 'is already on the remote, so removing it would break other '
                'copies of this repository'
          : 'has newer commits after it, so it cannot simply be removed';
      final push = repo.pushAfterCommit
          ? ' It will be pushed, because this repository pushes after '
                'each commit.'
          : '';
      final ok = await confirm(
        context,
        title: 'Cancel this commit?',
        message:
            '$name $where. Clotho will add a new commit that reverses its '
            'changes instead. Nothing is erased, and you can undo that '
            'commit too.$push\n\n'
            'Git: revert',
        action: 'Add cancelling commit',
      );
      if (!ok || !context.mounted) return false;
  }
  final outcome = await withIdentity(
    context,
    repo.app,
    () => repo.undoCommit(oid),
  );
  if (outcome == null || !context.mounted) return false;
  final r = outcome.result;
  if (r.kind == UndoKind.takeBack) {
    final backup = r.backup;
    final messenger = ScaffoldMessenger.maybeOf(context);
    showMessage(
      context,
      'Commit undone. Its changes are back in Changes.',
      actionLabel: backup != null ? 'Redo' : null,
      onAction: backup == null
          ? null
          : () async {
              try {
                await repo.redoUndo(backup);
                messenger?.showSnackBar(
                  const SnackBar(
                    content: Text('Commit restored.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } catch (e) {
                messenger?.showSnackBar(
                  SnackBar(
                    content: Text(describeError(e)),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
    );
  } else if (outcome.pushError != null) {
    showMessage(
      context,
      'Added a commit that cancels $name, but push failed: '
      '${outcome.pushError}',
      error: true,
    );
  } else if (outcome.push != null) {
    showMessage(context, 'Added and pushed a commit that cancels $name.');
  } else {
    showMessage(context, 'Added a commit that cancels $name.');
  }
  return true;
}
