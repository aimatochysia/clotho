import 'package:flutter/material.dart';

import '../core/git_service.dart';
import '../state/app_controller.dart';
import '../state/repo_controller.dart';
import 'branches_tab.dart';
import 'changes_tab.dart';
import 'dashboard_page.dart' show pullMessage;
import 'history_tab.dart';
import 'settings_page.dart';
import 'widgets/feedback.dart';

class RepoPage extends StatefulWidget {
  const RepoPage({super.key, required this.app, required this.path});
  final AppController app;
  final String path;

  @override
  State<RepoPage> createState() => _RepoPageState();
}

class _RepoPageState extends State<RepoPage> {
  late final RepoController repo = RepoController(
    app: widget.app,
    path: widget.path,
  );

  @override
  void initState() {
    super.initState();
    repo.open();
  }

  @override
  void dispose() {
    repo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final s = repo.status;
        final entry = widget.app.entryFor(widget.path);
        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry?.name ?? widget.path),
                  if (s != null)
                    Text(
                      [
                        s.branch ?? 'detached HEAD',
                        if (s.upstream != null) '→ ${s.upstream}',
                      ].join(' '),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
              actions: [
                if (repo.busy)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                IconButton(
                  key: const Key('fetch'),
                  tooltip: 'Fetch',
                  onPressed: repo.busy
                      ? null
                      : () => guarded(
                          context,
                          repo.fetch,
                          success: (_) => 'Fetched',
                        ),
                  icon: const Icon(Icons.sync),
                ),
                _PullButton(repo: repo),
                IconButton(
                  key: const Key('push'),
                  tooltip: s != null && s.ahead > 0
                      ? 'Push ${s.ahead} commit(s)'
                      : 'Push',
                  onPressed: repo.busy
                      ? null
                      : () => guarded(
                          context,
                          repo.push,
                          success: (r) => 'Pushed to ${r.remote}/${r.branch}',
                        ),
                  icon: Badge(
                    isLabelVisible: s != null && s.ahead > 0,
                    label: Text('${s?.ahead ?? 0}'),
                    child: const Icon(Icons.upload),
                  ),
                ),
                if (entry != null)
                  IconButton(
                    tooltip: 'Repository settings',
                    icon: const Icon(Icons.tune),
                    onPressed: () =>
                        showRepoSettings(context, widget.app, entry),
                  ),
              ],
              bottom: TabBar(
                tabs: [
                  Tab(
                    text: s == null || s.files.isEmpty
                        ? 'Changes'
                        : 'Changes (${s.files.length})',
                  ),
                  const Tab(text: 'Branches'),
                  const Tab(text: 'History'),
                ],
              ),
            ),
            body: s == null
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    children: [
                      ChangesTab(repo: repo),
                      BranchesTab(repo: repo),
                      HistoryTab(repo: repo),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _PullButton extends StatelessWidget {
  const _PullButton({required this.repo});
  final RepoController repo;

  @override
  Widget build(BuildContext context) {
    final s = repo.status;
    final strategy = repo.app.pullStrategyFor(repo.path);
    return MenuAnchor(
      menuChildren: [
        for (final p in PullStrategy.values)
          MenuItemButton(
            leadingIcon: Icon(
              p == strategy
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
            ),
            onPressed: () => guarded(
              context,
              () => repo.pull(strategy: p),
              success: pullMessage,
            ),
            child: Text('Pull: ${pullStrategyLabel(p)}'),
          ),
      ],
      builder: (context, menu, _) => GestureDetector(
        onLongPress: () => menu.open(),
        onSecondaryTap: () => menu.open(),
        child: IconButton(
          key: const Key('pull'),
          tooltip:
              'Pull (${pullStrategyLabel(strategy)}). Long-press or right-click for options.',
          onPressed: repo.busy
              ? null
              : () => guarded(context, () => repo.pull(), success: pullMessage),
          icon: Badge(
            isLabelVisible: s != null && s.behind > 0,
            label: Text('${s?.behind ?? 0}'),
            child: const Icon(Icons.download),
          ),
        ),
      ),
    );
  }
}
