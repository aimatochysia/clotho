import 'package:flutter/material.dart';

import '../core/git_service.dart';
import '../state/app_controller.dart';
import 'add_repo.dart';
import 'github/clone.dart';
import 'github/repos_page.dart';
import 'github/sign_in.dart';
import 'repo_page.dart';
import 'settings_page.dart';
import 'update_ui.dart';
import 'widgets/feedback.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.app});
  final AppController app;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String _filter = '';
  late final AppLifecycleListener _lifecycle;

  AppController get app => widget.app;

  @override
  void initState() {
    super.initState();
    // Coming back to the app is a good moment to refresh every status.
    _lifecycle = AppLifecycleListener(onResume: app.refreshAll);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _open(RepoView r) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RepoPage(app: app, path: r.entry.path),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final repos = app.repos
            .where(
              (r) =>
                  _filter.isEmpty ||
                  r.entry.name.toLowerCase().contains(_filter),
            )
            .toList();
        return Scaffold(
          appBar: AppBar(
            title: const Text('Clotho'),
            actions: [
              IconButton(
                key: const Key('fetch-all'),
                tooltip: 'Fetch all repositories',
                onPressed: app.fetchingAll || app.repos.isEmpty
                    ? null
                    : () => guarded(
                        context,
                        app.fetchAll,
                        success: (_) => 'Fetched all repositories',
                      ),
                icon: app.fetchingAll
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
              ),
              const AccountButton(),
              IconButton(
                tooltip: 'Settings',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => SettingsPage(app: app)),
                ),
              ),
            ],
          ),
          floatingActionButton: _AddMenu(app: app),
          body: !app.loaded
              ? const Center(child: CircularProgressIndicator())
              : app.repos.isEmpty
              ? _EmptyState(app: app)
              : RefreshIndicator(
                  onRefresh: app.refreshAll,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                    children: [
                      const UpdateBanner(),
                      if (app.repos.length > 6)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: TextField(
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              hintText: 'Filter repositories',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (v) =>
                                setState(() => _filter = v.toLowerCase()),
                          ),
                        ),
                      for (final r in repos)
                        RepoCard(app: app, repo: r, onOpen: () => _open(r)),
                    ],
                  ),
                ),
        );
      },
    );
  }
}

class _AddMenu extends StatelessWidget {
  const _AddMenu({required this.app});
  final AppController app;

  @override
  Widget build(BuildContext context) => MenuAnchor(
    menuChildren: [
      MenuItemButton(
        leadingIcon: const Icon(Icons.create_new_folder_outlined),
        onPressed: () => addRepository(context, app),
        child: const Text('Add repository folder'),
      ),
      MenuItemButton(
        leadingIcon: const Icon(Icons.travel_explore),
        onPressed: () => scanFolder(context, app),
        child: const Text('Scan a folder for repositories'),
      ),
      MenuItemButton(
        key: const Key('menu-clone-github'),
        leadingIcon: const Icon(Icons.cloud_download_outlined),
        onPressed: () => openGitHubRepos(context, app),
        child: const Text('Clone from GitHub'),
      ),
      MenuItemButton(
        leadingIcon: const Icon(Icons.link),
        onPressed: () => cloneRepository(context, app),
        child: const Text('Clone from URL'),
      ),
    ],
    builder: (context, menu, _) => FloatingActionButton.extended(
      key: const Key('add-repo'),
      onPressed: () => menu.isOpen ? menu.close() : menu.open(),
      icon: const Icon(Icons.add),
      label: const Text('Add'),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.app});
  final AppController app;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const UpdateBanner(),
          Icon(
            Icons.folder_open,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'No repositories yet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Add a folder that contains a Git repository, scan a parent folder '
            'to add many at once, or clone one from GitHub. Clotho never moves '
            'your files.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: () => addRepository(context, app),
                icon: const Icon(Icons.create_new_folder_outlined),
                label: const Text('Add repository'),
              ),
              OutlinedButton.icon(
                onPressed: () => scanFolder(context, app),
                icon: const Icon(Icons.travel_explore),
                label: const Text('Scan folder'),
              ),
              OutlinedButton.icon(
                onPressed: () => openGitHubRepos(context, app),
                icon: const Icon(Icons.cloud_download_outlined),
                label: const Text('Clone from GitHub'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class RepoCard extends StatelessWidget {
  const RepoCard({
    super.key,
    required this.app,
    required this.repo,
    required this.onOpen,
  });

  final AppController app;
  final RepoView repo;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = repo.status;
    final path = repo.entry.path;
    final busy = app.isBusy(path);
    return Card(
      key: Key('repo-$path'),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: repo.error == null ? onOpen : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      repo.entry.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      path,
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    if (repo.error != null)
                      Text(repo.error!, style: TextStyle(color: scheme.error))
                    else if (s != null)
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          Pill(s.branch ?? 'detached', icon: Icons.call_split),
                          if (s.state != RepoState.clean)
                            Pill(
                              s.state.name,
                              icon: Icons.warning_amber,
                              color: scheme.tertiaryContainer,
                            ),
                          if (s.ahead > 0)
                            Pill('↑${s.ahead}', tooltip: '${s.ahead} to push'),
                          if (s.behind > 0)
                            Pill(
                              '↓${s.behind}',
                              tooltip: '${s.behind} to pull',
                            ),
                          if (s.files.isNotEmpty)
                            Pill(
                              '${s.files.length} changed',
                              color: scheme.primaryContainer,
                            )
                          else
                            Pill(
                              'clean',
                              icon: Icons.check,
                              color: scheme.surfaceContainerHighest,
                            ),
                          if (s.upstream == null && s.branch != null)
                            Pill(
                              'not pushed',
                              color: scheme.surfaceContainerHighest,
                            ),
                          if (repo.fetchError != null)
                            Pill(
                              'fetch failed',
                              icon: Icons.cloud_off,
                              color: scheme.errorContainer,
                              tooltip: repo.fetchError,
                            ),
                        ],
                      )
                    else
                      const LinearProgressIndicator(),
                  ],
                ),
              ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                _RepoMenu(app: app, repo: repo),
            ],
          ),
        ),
      ),
    );
  }
}

class _RepoMenu extends StatelessWidget {
  const _RepoMenu({required this.app, required this.repo});
  final AppController app;
  final RepoView repo;

  @override
  Widget build(BuildContext context) {
    final path = repo.entry.path;
    return PopupMenuButton<String>(
      tooltip: 'Actions',
      onSelected: (v) async {
        switch (v) {
          case 'fetch':
            await guarded(
              context,
              () => app.fetch(path),
              success: (_) => 'Fetched ${repo.entry.name}',
            );
          case 'pull':
            await guarded(
              context,
              () => app.pull(path),
              success: (r) => pullMessage(r),
            );
          case 'push':
            await guarded(
              context,
              () => app.push(path),
              success: (r) => 'Pushed to ${r.remote}/${r.branch}',
            );
          case 'settings':
            await showRepoSettings(context, app, repo.entry);
          case 'remove':
            final ok = await confirm(
              context,
              title: 'Remove ${repo.entry.name}?',
              message: 'It is removed from Clotho only. The folder and its files stay on disk.',
              action: 'Remove',
            );
            if (ok && context.mounted) {
              await guarded(context, () => app.removeRepo(path));
            }
        }
      },
      itemBuilder: (_) => [
        if (repo.error == null) ...const [
          PopupMenuItem(value: 'fetch', child: Text('Fetch')),
          PopupMenuItem(value: 'pull', child: Text('Pull')),
          PopupMenuItem(value: 'push', child: Text('Push')),
          PopupMenuDivider(),
        ],
        const PopupMenuItem(
          value: 'settings',
          child: Text('Repository settings'),
        ),
        const PopupMenuItem(value: 'remove', child: Text('Remove from list')),
      ],
    );
  }
}

String pullMessage(PullResult r) => switch (r.outcome) {
  PullOutcome.upToDate => 'Already up to date',
  PullOutcome.fastForwarded =>
    'Pulled ${r.newCommits} new commit${r.newCommits == 1 ? '' : 's'}',
  PullOutcome.merged =>
    'Merged ${r.newCommits} commit${r.newCommits == 1 ? '' : 's'} from the remote',
  PullOutcome.rebased =>
    'Rebased onto ${r.newCommits} new commit${r.newCommits == 1 ? '' : 's'}',
};
