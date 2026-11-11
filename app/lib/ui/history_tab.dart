import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/git_service.dart';
import '../state/repo_controller.dart';
import 'widgets/commit_graph.dart';
import 'widgets/diff_view.dart';
import 'widgets/feedback.dart';

class HistoryTab extends StatelessWidget {
  const HistoryTab({super.key, required this.repo});
  final RepoController repo;

  @override
  Widget build(BuildContext context) {
    final commits = repo.history;
    final graph = computeGraph(commits);
    final maxWidth = graph.fold<int>(1, (m, r) => math.max(m, r.width));
    final headOid = repo.branches?.where((b) => b.isHead).firstOrNull?.shortOid;
    final remoteRefs = {
      for (final b in repo.branches ?? const <BranchInfo>[])
        if (b.isRemote) b.name,
    };
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Text('${commits.length}${repo.historyDone ? '' : '+'} commits'),
              const Spacer(),
              const Text('All branches'),
              Switch(
                key: const Key('all-branches'),
                value: repo.allBranches,
                onChanged: repo.setAllBranches,
              ),
            ],
          ),
        ),
        Expanded(
          child: commits.isEmpty
              ? Center(
                  child: repo.loadingHistory
                      ? const CircularProgressIndicator()
                      : Text(repo.historyError ?? 'No commits yet'),
                )
              : NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n.metrics.extentAfter < 600 && !repo.historyDone) {
                      repo.loadHistory();
                    }
                    return false;
                  },
                  child: ListView.builder(
                    itemCount: commits.length + (repo.historyDone ? 0 : 1),
                    itemExtent: 56,
                    itemBuilder: (context, i) {
                      if (i >= commits.length) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final c = commits[i];
                      return _CommitRow(
                        commit: c,
                        row: graph[i],
                        maxWidth: maxWidth,
                        isHead: c.shortOid == headOid,
                        remoteRefs: remoteRefs,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CommitPage(repo: repo, commit: c),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _CommitRow extends StatelessWidget {
  const _CommitRow({
    required this.commit,
    required this.row,
    required this.maxWidth,
    required this.isHead,
    required this.remoteRefs,
    required this.onTap,
  });
  final Set<String> remoteRefs;
  final CommitInfo commit;
  final GraphRow row;
  final int maxWidth;
  final bool isHead;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          const SizedBox(width: 8),
          GraphCell(row: row, maxWidth: maxWidth, isHead: isHead),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    for (final r in commit.refs.take(3)) ...[
                      Pill(
                        r,
                        color: remoteRefs.contains(r)
                            ? scheme.surfaceContainerHighest
                            : laneColor(row.column).withValues(alpha: 0.25),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text(
                        commit.summary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: isHead ? FontWeight.bold : null,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${commit.shortOid} · ${commit.authorName} · ${relativeTime(commit.time.toInt())}',
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

/// Commit details: message, author, and the diff of every file it changed.
class CommitPage extends StatefulWidget {
  const CommitPage({super.key, required this.repo, required this.commit});
  final RepoController repo;
  final CommitInfo commit;

  @override
  State<CommitPage> createState() => _CommitPageState();
}

class _CommitPageState extends State<CommitPage> {
  late final Future<List<FileDiff>> _files = widget.repo.git.commitDiff(
    widget.repo.path,
    widget.commit.oid,
  );

  @override
  Widget build(BuildContext context) {
    final c = widget.commit;
    return Scaffold(
      appBar: AppBar(
        title: Text(c.shortOid),
        actions: [
          IconButton(
            tooltip: 'New branch from this commit',
            icon: const Icon(Icons.call_split),
            onPressed: () async {
              final name = await promptText(
                context,
                title: 'New branch at ${c.shortOid}',
                label: 'Branch name',
                action: 'Create & check out',
              );
              if (name != null && name.isNotEmpty && context.mounted) {
                await guarded(
                  context,
                  () => widget.repo.createBranch(name, from: c.oid),
                  success: (_) => 'Switched to new branch $name',
                );
              }
            },
          ),
        ],
      ),
      body: FutureBuilder(
        future: _files,
        builder: (context, snap) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SelectableText(
                c.message.trim(),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '${c.authorName} <${c.authorEmail}> · ${relativeTime(c.time.toInt())}',
              ),
              SelectableText(
                c.oid,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              if (snap.hasError) Text('$snap.error'),
              if (!snap.hasData && !snap.hasError)
                const Center(child: CircularProgressIndicator()),
              for (final f in snap.data ?? const <FileDiff>[])
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: ExpansionTile(
                    initiallyExpanded: (snap.data!.length) <= 5,
                    title: Text(
                      f.oldPath != null ? '${f.oldPath} → ${f.path}' : f.path,
                    ),
                    trailing: DiffStat(
                      additions: f.additions,
                      deletions: f.deletions,
                    ),
                    children: [DiffView(diff: f, shrinkWrap: true)],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
