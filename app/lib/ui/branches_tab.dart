import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/git_service.dart';
import '../src/rust/error.dart';
import '../state/repo_controller.dart';
import 'widgets/feedback.dart';

class BranchesTab extends StatelessWidget {
  const BranchesTab({super.key, required this.repo});
  final RepoController repo;

  Future<void> _create(BuildContext context, {String? from}) async {
    final name = await promptText(
      context,
      title: from == null ? 'New branch' : 'New branch from $from',
      label: 'Branch name',
      hint: 'feature/my-change',
      action: 'Create & check out',
    );
    if (name == null || name.isEmpty || !context.mounted) return;
    await guarded(
      context,
      () => repo.createBranch(name, from: from),
      success: (_) => 'Switched to new branch $name',
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = repo.branches;
    if (list == null) {
      return Center(
        child: repo.branchesError != null
            ? Text(repo.branchesError!)
            : const CircularProgressIndicator(),
      );
    }
    final local = list.where((b) => !b.isRemote).toList();
    final remote = list.where((b) => b.isRemote).toList();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('new-branch'),
        onPressed: () => _create(context),
        icon: const Icon(Icons.add),
        label: const Text('New branch'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          _header(context, 'Local branches (${local.length})'),
          for (final b in local)
            _BranchTile(
              repo: repo,
              branch: b,
              onBranchFrom: () => _create(context, from: b.name),
            ),
          if (remote.isNotEmpty)
            _header(context, 'Remote branches (${remote.length})'),
          for (final b in remote)
            _BranchTile(
              repo: repo,
              branch: b,
              onBranchFrom: () => _create(context, from: b.name),
            ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(text, style: Theme.of(context).textTheme.labelLarge),
  );
}

class _BranchTile extends StatelessWidget {
  const _BranchTile({
    required this.repo,
    required this.branch,
    required this.onBranchFrom,
  });
  final RepoController repo;
  final BranchInfo branch;
  final VoidCallback onBranchFrom;

  Future<void> _delete(BuildContext context) async {
    final ok = await confirm(
      context,
      title: 'Delete branch ${branch.name}?',
      message: 'The branch is deleted locally. Commits stay reachable from other branches.',
      action: 'Delete',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    try {
      await repo.deleteBranch(branch.name);
      if (context.mounted) showMessage(context, 'Deleted ${branch.name}');
    } on CoreError_BranchNotMerged {
      if (!context.mounted) return;
      final force = await confirm(
        context,
        title: '${branch.name} is not merged',
        message: 'It has commits that are in no other branch. Deleting it may lose that work. Delete anyway?',
        action: 'Delete anyway',
        destructive: true,
      );
      if (force && context.mounted) {
        await guarded(
          context,
          () => repo.deleteBranch(branch.name, force: true),
          success: (_) => 'Deleted ${branch.name}',
        );
      }
    } catch (e) {
      if (context.mounted) await guarded(context, () => Future<void>.error(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = branch;
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      key: Key('branch-${b.name}'),
      leading: Icon(
        b.isHead
            ? Icons.radio_button_checked
            : (b.isRemote ? Icons.cloud_outlined : Icons.call_split),
        color: b.isHead ? scheme.primary : null,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              b.name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: b.isHead ? FontWeight.bold : null),
            ),
          ),
          if (b.ahead > 0) ...[const SizedBox(width: 6), Pill('↑${b.ahead}')],
          if (b.behind > 0) ...[const SizedBox(width: 6), Pill('↓${b.behind}')],
        ],
      ),
      subtitle: Text(
        '${b.shortOid} · ${b.summary} · ${relativeTime(b.time.toInt())}'
        '${b.upstream != null ? '\ntracks ${b.upstream}' : ''}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      isThreeLine: b.upstream != null,
      onTap: b.isHead
          ? null
          : () => guarded(
              context,
              () => repo.checkout(b.name),
              success: (_) => 'Switched to ${b.name}',
            ),
      trailing: PopupMenuButton<String>(
        onSelected: (v) async {
          switch (v) {
            case 'checkout':
              await guarded(
                context,
                () => repo.checkout(b.name),
                success: (_) => 'Switched to ${b.name}',
              );
            case 'from':
              onBranchFrom();
            case 'rename':
              final name = await promptText(
                context,
                title: 'Rename ${b.name}',
                initial: b.name,
                action: 'Rename',
              );
              if (name != null &&
                  name.isNotEmpty &&
                  name != b.name &&
                  context.mounted) {
                await guarded(context, () => repo.renameBranch(b.name, name));
              }
            case 'delete':
              await _delete(context);
          }
        },
        itemBuilder: (_) => [
          if (!b.isHead)
            const PopupMenuItem(value: 'checkout', child: Text('Check out')),
          const PopupMenuItem(
            value: 'from',
            child: Text('New branch from here'),
          ),
          if (!b.isRemote)
            const PopupMenuItem(value: 'rename', child: Text('Rename')),
          if (!b.isRemote && !b.isHead)
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
    );
  }
}
