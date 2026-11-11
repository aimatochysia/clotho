import 'package:flutter/material.dart';

import '../core/git_service.dart';
import '../state/repo_controller.dart';
import 'identity.dart';
import 'widgets/binary_preview.dart';
import 'widgets/diff_view.dart';
import 'widgets/feedback.dart';

class ChangesTab extends StatelessWidget {
  const ChangesTab({super.key, required this.repo});
  final RepoController repo;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 900;
        final list = _ChangeList(
          repo: repo,
          onOpen: wide ? null : (sel) => _openDiff(context, sel),
        );
        if (!wide) return list;
        return Row(
          children: [
            SizedBox(width: 380, child: list),
            const VerticalDivider(width: 1),
            Expanded(child: _DiffPane(repo: repo)),
          ],
        );
      },
    );
  }

  void _openDiff(BuildContext context, FileSelection sel) {
    repo.select(sel);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(sel.path.split('/').last)),
          body: ListenableBuilder(
            listenable: repo,
            builder: (_, _) => _DiffPane(repo: repo),
          ),
        ),
      ),
    );
  }
}

class _DiffPane extends StatelessWidget {
  const _DiffPane({required this.repo});
  final RepoController repo;

  @override
  Widget build(BuildContext context) {
    if (repo.selection == null) {
      return const Center(child: Text('Select a file to see its changes'));
    }
    if (repo.loadingDiff && repo.diff == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (repo.diffError != null) return Center(child: Text(repo.diffError!));
    final d = repo.diff;
    if (d == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${d.oldPath != null ? '${d.oldPath} → ' : ''}${d.path}'
                  '${repo.selection!.staged ? '  (staged)' : ''}',
                  style: Theme.of(context).textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DiffStat(additions: d.additions, deletions: d.deletions),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: DiffView(
            diff: d,
            binary: BinaryPreview(
              // One preview per selected file; a fresh diff only reloads it
              // quietly, so watcher refreshes do not make it flicker.
              key: ValueKey('${d.path}:${repo.selection!.staged}'),
              revision: d,
              file: d.path,
              git: repo.git,
              load: () => repo.git.workingFileVersions(
                repo.path,
                d.path,
                staged: repo.selection!.staged,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

String changeLetter(ChangeKind k) => switch (k) {
  ChangeKind.added => 'A',
  ChangeKind.modified => 'M',
  ChangeKind.deleted => 'D',
  ChangeKind.renamed => 'R',
  ChangeKind.typeChanged => 'T',
  ChangeKind.untracked => 'U',
};

Color changeColor(ChangeKind k) => switch (k) {
  ChangeKind.added || ChangeKind.untracked => const Color(0xFF1A7F37),
  ChangeKind.deleted => const Color(0xFFCF222E),
  ChangeKind.renamed => const Color(0xFF8250DF),
  _ => const Color(0xFF9A6700),
};

class _ChangeList extends StatelessWidget {
  const _ChangeList({required this.repo, required this.onOpen});
  final RepoController repo;
  final void Function(FileSelection)? onOpen;

  @override
  Widget build(BuildContext context) {
    final s = repo.status!;
    final staged = s.files.where((f) => f.staged != null).toList();
    final unstaged = s.files
        .where((f) => f.unstaged != null || (f.conflicted && f.staged == null))
        .toList();
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        if (s.state != RepoState.clean)
          MaterialBanner(
            content: Text(switch (s.state) {
              RepoState.merging => 'Merge in progress. Resolve conflicts, stage the files, then commit.',
              RepoState.rebasing =>
                'Rebase in progress. Finish or abort it with Git.',
              _ =>
                'Repository is in the middle of an operation (${s.state.name}).',
            }),
            backgroundColor: scheme.tertiaryContainer,
            actions: const [SizedBox.shrink()],
          ),
        Expanded(
          child: s.files.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline, size: 48),
                      SizedBox(height: 8),
                      Text('Working tree clean. Nothing to commit.'),
                    ],
                  ),
                )
              : ListView(
                  children: [
                    if (staged.isNotEmpty)
                      _SectionHeader(
                        title: 'Staged (${staged.length})',
                        action: TextButton(
                          onPressed: () => guarded(
                            context,
                            () =>
                                repo.unstage([for (final f in staged) f.path]),
                          ),
                          child: const Text('Unstage all'),
                        ),
                      ),
                    for (final f in staged)
                      _FileRow(
                        repo: repo,
                        file: f,
                        staged: true,
                        onOpen: onOpen,
                      ),
                    if (unstaged.isNotEmpty)
                      _SectionHeader(
                        title: 'Changes (${unstaged.length})',
                        action: TextButton(
                          key: const Key('stage-all'),
                          onPressed: () => guarded(context, repo.stageAll),
                          child: const Text('Stage all'),
                        ),
                      ),
                    for (final f in unstaged)
                      _FileRow(
                        repo: repo,
                        file: f,
                        staged: false,
                        onOpen: onOpen,
                      ),
                  ],
                ),
        ),
        const Divider(height: 1),
        CommitBox(repo: repo),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.action});
  final String title;
  final Widget action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.labelLarge),
        ),
        action,
      ],
    ),
  );
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.repo,
    required this.file,
    required this.staged,
    required this.onOpen,
  });
  final RepoController repo;
  final FileChange file;
  final bool staged;
  final void Function(FileSelection)? onOpen;

  @override
  Widget build(BuildContext context) {
    final kind = staged ? file.staged : file.unstaged;
    final sel = FileSelection(file.path, staged: staged);
    final selected = repo.selection == sel;
    final name = file.path.split('/').last;
    final dir = file.path.contains('/')
        ? file.path.substring(0, file.path.lastIndexOf('/'))
        : '';
    return ListTile(
      key: Key('file-${staged ? 's' : 'u'}-${file.path}'),
      dense: true,
      selected: selected,
      leading: file.conflicted
          ? const Icon(Icons.report, color: Color(0xFFCF222E))
          : Text(
              kind == null ? '?' : changeLetter(kind),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: kind == null ? null : changeColor(kind),
              ),
            ),
      title: Text(name, overflow: TextOverflow.ellipsis),
      subtitle: dir.isEmpty ? null : Text(dir, overflow: TextOverflow.ellipsis),
      onTap: () => onOpen != null ? onOpen!(sel) : repo.select(sel),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!staged && !file.conflicted)
            IconButton(
              tooltip: 'Discard changes',
              icon: const Icon(Icons.undo, size: 20),
              onPressed: () async {
                final ok = await confirm(
                  context,
                  title: 'Discard changes to $name?',
                  message: kind == ChangeKind.untracked
                      ? 'This new file will be deleted. This cannot be undone.'
                      : 'Your edits to this file will be lost. This cannot be undone.',
                  action: 'Discard',
                  destructive: true,
                );
                if (ok && context.mounted) {
                  await guarded(context, () => repo.discard([file.path]));
                }
              },
            ),
          IconButton(
            key: Key('${staged ? 'unstage' : 'stage'}-${file.path}'),
            tooltip: staged ? 'Unstage' : 'Stage',
            icon: Icon(
              staged ? Icons.remove_circle_outline : Icons.add_circle_outline,
              size: 20,
            ),
            onPressed: () => guarded(
              context,
              () =>
                  staged ? repo.unstage([file.path]) : repo.stage([file.path]),
            ),
          ),
        ],
      ),
    );
  }
}

/// Message box + Commit button. The button stays disabled until there is
/// something to commit (the no-diff check), and its label says whether the
/// commit will also be pushed.
class CommitBox extends StatefulWidget {
  const CommitBox({super.key, required this.repo});
  final RepoController repo;

  @override
  State<CommitBox> createState() => _CommitBoxState();
}

class _CommitBoxState extends State<CommitBox> {
  final _message = TextEditingController();
  bool _working = false;

  RepoController get repo => widget.repo;

  @override
  void initState() {
    super.initState();
    _message.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _commit() async {
    setState(() => _working = true);
    final outcome = await withIdentity(
      context,
      repo.app,
      () => repo.commit(_message.text),
    );
    if (!mounted) return;
    setState(() => _working = false);
    if (outcome == null) return;
    _message.clear();
    final c = outcome.commit;
    if (outcome.pushError != null) {
      showMessage(
        context,
        'Committed ${c.shortOid}, but push failed: ${outcome.pushError}',
        error: true,
      );
    } else if (outcome.push != null) {
      showMessage(
        context,
        'Committed ${c.shortOid} and pushed to ${outcome.push!.remote}/${outcome.push!.branch}',
      );
    } else {
      showMessage(context, 'Committed ${c.shortOid}: ${c.summary}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = repo.status!;
    final hasMessage = _message.text.trim().isNotEmpty;
    final enabled = repo.canCommit && hasMessage && !_working && !repo.busy;
    final reason = s.conflictedCount > 0
        ? 'Resolve conflicts first'
        : !repo.canCommit
        ? (s.files.isEmpty
              ? 'No changes to commit'
              : 'Stage changes or turn on "Commit all"')
        : !hasMessage
        ? 'Write a commit message'
        : null;
    final label = repo.amend
        ? 'Amend last commit'
        : repo.pushAfterCommit
        ? 'Commit & push'
        : 'Commit';

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('commit-message'),
            controller: _message,
            minLines: 1,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'Commit message (e.g. feat: add login)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            children: [
              FilterChip(
                key: const Key('commit-all'),
                label: const Text('Commit all changes'),
                selected: repo.stageAllOnCommit,
                onSelected: repo.setStageAllOnCommit,
              ),
              FilterChip(
                label: const Text('Amend'),
                selected: repo.amend,
                onSelected: repo.setAmend,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Tooltip(
            message: reason ?? '',
            child: FilledButton.icon(
              key: const Key('commit-button'),
              onPressed: enabled ? _commit : null,
              icon: _working
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      repo.pushAfterCommit ? Icons.cloud_upload : Icons.check,
                    ),
              label: Text(label),
            ),
          ),
          if (reason != null && !_working)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                reason,
                key: const Key('commit-reason'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}
