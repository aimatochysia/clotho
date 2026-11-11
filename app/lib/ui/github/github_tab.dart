import 'package:flutter/material.dart';

import '../../core/errors.dart';
import '../../core/format.dart';
import '../../core/github_service.dart';
import '../../state/github_scope.dart';
import 'repos_page.dart' show ErrorView;
import 'sign_in.dart';

enum _Section { pulls, issues, runs }

/// Pull requests, issues and Actions runs of the repository's GitHub remote.
class GitHubTab extends StatefulWidget {
  const GitHubTab({super.key, required this.remote, this.branch});
  final GitHubRemote remote;

  /// The current local branch, used for the "new pull request" link.
  final String? branch;

  @override
  State<GitHubTab> createState() => _GitHubTabState();
}

class _GitHubTabState extends State<GitHubTab>
    with AutomaticKeepAliveClientMixin {
  _Section _section = _Section.pulls;
  bool _closed = false;
  Future<List<Object>>? _items;

  @override
  bool get wantKeepAlive => true;

  String get _slug => '${widget.remote.owner}/${widget.remote.repo}';
  String get _web => 'https://github.com/$_slug';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _items ??= _load();
  }

  Future<List<Object>> _load() {
    final scope = GitHubScope.of(context);
    final t = scope.auth.token;
    final o = widget.remote.owner, r = widget.remote.repo;
    final state = _closed ? 'closed' : 'open';
    return switch (_section) {
      _Section.pulls => scope.github.pulls(t, o, r, state: state),
      _Section.issues => scope.github.issues(t, o, r, state: state),
      _Section.runs => scope.github.runs(t, o, r),
    };
  }

  void _reload() => setState(() => _items = _load());

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final branch = widget.branch;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedButton<_Section>(
                segments: const [
                  ButtonSegment(
                    value: _Section.pulls,
                    icon: Icon(Icons.merge_type),
                    label: Text('Pull requests'),
                  ),
                  ButtonSegment(
                    value: _Section.issues,
                    icon: Icon(Icons.adjust),
                    label: Text('Issues'),
                  ),
                  ButtonSegment(
                    value: _Section.runs,
                    icon: Icon(Icons.play_circle_outline),
                    label: Text('Actions'),
                  ),
                ],
                selected: {_section},
                onSelectionChanged: (s) {
                  _section = s.first;
                  _reload();
                },
              ),
              if (_section != _Section.runs)
                FilterChip(
                  label: const Text('Closed'),
                  selected: _closed,
                  onSelected: (v) {
                    _closed = v;
                    _reload();
                  },
                ),
              IconButton(
                tooltip: 'Reload',
                icon: const Icon(Icons.refresh),
                onPressed: _reload,
              ),
              TextButton.icon(
                onPressed: () => openUrl(context, switch (_section) {
                  _Section.pulls when branch != null =>
                    '$_web/compare/${Uri.encodeComponent(branch)}?expand=1',
                  _Section.pulls => '$_web/pulls',
                  _Section.issues => '$_web/issues/new',
                  _Section.runs => '$_web/actions',
                }),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text(switch (_section) {
                  _Section.pulls => 'New pull request',
                  _Section.issues => 'New issue',
                  _Section.runs => 'Open Actions',
                }),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Object>>(
            future: _items,
            builder: (context, snap) {
              if (snap.hasError) {
                return ErrorView(
                  message: describeError(snap.error!),
                  onRetry: _reload,
                );
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = snap.data!;
              if (items.isEmpty) {
                return Center(
                  child: Text(switch (_section) {
                    _Section.pulls =>
                      'No ${_closed ? 'closed' : 'open'} pull requests',
                    _Section.issues =>
                      'No ${_closed ? 'closed' : 'open'} issues',
                    _Section.runs => 'No workflow runs yet',
                  }),
                );
              }
              return RefreshIndicator(
                onRefresh: () async {
                  _reload();
                  await _items;
                },
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) => _tile(context, items[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _tile(BuildContext context, Object item) {
    final scheme = Theme.of(context).colorScheme;
    return switch (item) {
      GitHubPull p => ListTile(
        leading: Icon(
          Icons.merge_type,
          color: p.draft ? scheme.outline : scheme.primary,
        ),
        title: Text('${p.title}  #${p.number}'),
        subtitle: Text(
          '${p.headRef} → ${p.baseRef} · ${p.author}'
          '${p.draft ? ' · draft' : ''} · updated ${relativeIso(p.updatedAt)}',
        ),
        onTap: () => openUrl(context, p.htmlUrl),
      ),
      GitHubIssue i => ListTile(
        leading: Icon(
          i.state == 'open' ? Icons.adjust : Icons.check_circle_outline,
          color: i.state == 'open' ? scheme.primary : scheme.outline,
        ),
        title: Text('${i.title}  #${i.number}'),
        subtitle: Text(
          [
            i.author,
            if (i.labels.isNotEmpty) i.labels.join(', '),
            if (i.comments > 0) '${i.comments} comments',
            'updated ${relativeIso(i.updatedAt)}',
          ].join(' · '),
        ),
        onTap: () => openUrl(context, i.htmlUrl),
      ),
      WorkflowRun r => ListTile(
        leading: _RunIcon(run: r),
        title: Text(r.title.isEmpty ? r.name : r.title),
        subtitle: Text(
          '${r.name} #${r.runNumber} · ${r.branch} · ${r.event} · '
          '${relativeIso(r.createdAt)}',
        ),
        onTap: () => openUrl(context, r.htmlUrl),
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _RunIcon extends StatelessWidget {
  const _RunIcon({required this.run});
  final WorkflowRun run;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (run.status != 'completed') {
      return Tooltip(
        message: run.status,
        child: Icon(Icons.pending_outlined, color: scheme.tertiary),
      );
    }
    final (icon, color) = switch (run.conclusion) {
      'success' => (Icons.check_circle, Colors.green),
      'failure' || 'timed_out' => (Icons.cancel, scheme.error),
      'cancelled' => (Icons.block, scheme.outline),
      _ => (Icons.remove_circle_outline, scheme.outline),
    };
    return Tooltip(
      message: run.conclusion ?? '',
      child: Icon(icon, color: color),
    );
  }
}
