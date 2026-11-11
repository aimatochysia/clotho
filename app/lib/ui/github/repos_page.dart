import 'package:flutter/material.dart';

import '../../core/errors.dart';
import '../../core/format.dart';
import '../../core/github_service.dart';
import '../../state/app_controller.dart';
import '../../state/github_scope.dart';
import 'clone.dart';
import 'sign_in.dart';

/// Opens the GitHub repository browser, asking to sign in first if needed.
Future<void> openGitHubRepos(BuildContext context, AppController app) async {
  final auth = GitHubScope.of(context).auth;
  if (!auth.signedIn && !await showSignIn(context)) return;
  if (!context.mounted) return;
  await Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => GitHubReposPage(app: app)));
}

/// Lists the signed-in user's repositories so they can be cloned.
class GitHubReposPage extends StatefulWidget {
  const GitHubReposPage({super.key, required this.app});
  final AppController app;

  @override
  State<GitHubReposPage> createState() => _GitHubReposPageState();
}

class _GitHubReposPageState extends State<GitHubReposPage> {
  List<GitHubRepo>? _repos;
  String? _error;
  String _filter = '';
  bool _hideArchived = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_repos == null && _error == null) _load();
  }

  Future<void> _load() async {
    final scope = GitHubScope.of(context);
    final token = scope.auth.token;
    if (token == null) {
      setState(() => _error = 'Sign in to GitHub first.');
      return;
    }
    setState(() => _error = null);
    try {
      final r = await scope.github.repos(token);
      if (mounted) setState(() => _repos = r);
    } catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final repos = (_repos ?? const <GitHubRepo>[]).where((r) {
      if (_hideArchived && r.archived) return false;
      if (_filter.isEmpty) return true;
      return r.fullName.toLowerCase().contains(_filter) ||
          (r.description?.toLowerCase().contains(_filter) ?? false);
    }).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your GitHub repositories'),
        actions: [
          IconButton(
            tooltip: 'Clone from URL',
            icon: const Icon(Icons.link),
            onPressed: () => cloneRepository(context, widget.app),
          ),
          IconButton(
            tooltip: 'Reload',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: TextField(
              key: const Key('gh-filter'),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Filter by name or description',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _filter = v.toLowerCase()),
            ),
          ),
          SwitchListTile(
            dense: true,
            title: const Text('Hide archived'),
            value: _hideArchived,
            onChanged: (v) => setState(() => _hideArchived = v),
          ),
          Expanded(
            child: _error != null
                ? ErrorView(message: _error!, onRetry: _load)
                : _repos == null
                ? const Center(child: CircularProgressIndicator())
                : repos.isEmpty
                ? const Center(child: Text('No repositories match'))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      itemCount: repos.length,
                      itemBuilder: (context, i) =>
                          _RepoTile(app: widget.app, repo: repos[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _RepoTile extends StatelessWidget {
  const _RepoTile({required this.app, required this.repo});
  final AppController app;
  final GitHubRepo repo;

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (repo.language != null) repo.language!,
      if (repo.stars > 0) '★ ${repo.stars}',
      if (repo.fork) 'fork',
      if (repo.archived) 'archived',
      if (repo.pushedAt != null) 'pushed ${relativeIso(repo.pushedAt)}',
    ].join(' · ');
    return ListTile(
      key: Key('gh-${repo.fullName}'),
      leading: Icon(repo.private ? Icons.lock_outline : Icons.public),
      title: Text(repo.fullName),
      subtitle: Text(
        [
          if (repo.description?.isNotEmpty ?? false) repo.description!,
          meta,
        ].join('\n'),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      isThreeLine: repo.description?.isNotEmpty ?? false,
      onTap: () => cloneRepository(context, app, url: repo.cloneUrl),
      trailing: IconButton(
        tooltip: 'Open on GitHub',
        icon: const Icon(Icons.open_in_new),
        onPressed: () => openUrl(context, repo.htmlUrl),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}
