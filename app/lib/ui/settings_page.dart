import 'package:flutter/material.dart';

import '../core/git_service.dart';
import '../state/app_controller.dart';
import 'widgets/feedback.dart';

String pullStrategyLabel(PullStrategy s) => switch (s) {
  PullStrategy.fastForwardOnly => 'Fast-forward only',
  PullStrategy.merge => 'Merge',
  PullStrategy.rebase => 'Rebase',
};

String pullStrategyHelp(PullStrategy s) => switch (s) {
  PullStrategy.fastForwardOnly =>
    'Safest: only pulls when your branch has no unpushed commits that diverge.',
  PullStrategy.merge =>
    'Creates a merge commit when both sides have new commits.',
  PullStrategy.rebase =>
    'Replays your commits on top of the remote ones for a straight history.',
};

const autoFetchChoices = [0, 1, 5, 15, 30, 60];

String autoFetchLabel(int m) => m == 0 ? 'Off' : 'Every $m min';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.app});
  final AppController app;

  AppSettings _with(
    AppSettings s, {
    int? autoFetchMinutes,
    PullStrategy? pullStrategy,
    bool? pushAfterCommit,
    int? scanDepth,
    bool? checkUpdates,
  }) => AppSettings(
    autoFetchMinutes: autoFetchMinutes ?? s.autoFetchMinutes,
    pullStrategy: pullStrategy ?? s.pullStrategy,
    pushAfterCommit: pushAfterCommit ?? s.pushAfterCommit,
    scanDepth: scanDepth ?? s.scanDepth,
    checkUpdates: checkUpdates ?? s.checkUpdates,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final s = app.settings;
          void save(AppSettings next) =>
              guarded(context, () => app.updateSettings(next));
          return ListView(
            children: [
              const _Header('Sync'),
              ListTile(
                leading: const Icon(Icons.sync),
                title: const Text('Auto fetch'),
                subtitle: const Text(
                  'Checks remotes in the background so ahead/behind counts stay current.',
                ),
                trailing: DropdownButton<int>(
                  key: const Key('auto-fetch'),
                  value: autoFetchChoices.contains(s.autoFetchMinutes)
                      ? s.autoFetchMinutes
                      : 5,
                  items: [
                    for (final m in autoFetchChoices)
                      DropdownMenuItem(
                        value: m,
                        child: Text(autoFetchLabel(m)),
                      ),
                  ],
                  onChanged: (m) => save(_with(s, autoFetchMinutes: m)),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('Pull strategy'),
                subtitle: Text(pullStrategyHelp(s.pullStrategy)),
                trailing: DropdownButton<PullStrategy>(
                  key: const Key('pull-strategy'),
                  value: s.pullStrategy,
                  items: [
                    for (final p in PullStrategy.values)
                      DropdownMenuItem(
                        value: p,
                        child: Text(pullStrategyLabel(p)),
                      ),
                  ],
                  onChanged: (p) => save(_with(s, pullStrategy: p)),
                ),
              ),
              SwitchListTile(
                key: const Key('push-after-commit'),
                secondary: const Icon(Icons.upload),
                title: const Text('Push after commit'),
                subtitle: Text(
                  s.pushAfterCommit
                      ? 'Every commit is pushed right away.'
                      : 'Commits stay local until you press Push.',
                ),
                value: s.pushAfterCommit,
                onChanged: (v) => save(_with(s, pushAfterCommit: v)),
              ),
              const _Header('Repositories'),
              ListTile(
                leading: const Icon(Icons.travel_explore),
                title: const Text('Scan depth'),
                subtitle: const Text(
                  'How many folders deep "Scan folder" looks.',
                ),
                trailing: DropdownButton<int>(
                  value: s.scanDepth.clamp(1, 8),
                  items: [
                    for (var d = 1; d <= 8; d++)
                      DropdownMenuItem(value: d, child: Text('$d')),
                  ],
                  onChanged: (d) => save(_with(s, scanDepth: d)),
                ),
              ),
              const _Header('Updates'),
              SwitchListTile(
                secondary: const Icon(Icons.system_update),
                title: const Text('Check for updates on start'),
                value: s.checkUpdates,
                onChanged: (v) => save(_with(s, checkUpdates: v)),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Each repository can override pull and push settings from its ⋮ menu.',
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelLarge
          ?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );
}

/// Per-repository overrides: display name, pull strategy, push after commit,
/// and whether it takes part in auto fetch.
Future<void> showRepoSettings(
  BuildContext context,
  AppController app,
  RepoEntry entry,
) async {
  final result = await showDialog<RepoEntry>(
    context: context,
    builder: (_) => _RepoSettingsDialog(entry: entry, defaults: app.settings),
  );
  if (result != null && context.mounted) {
    await guarded(
      context,
      () => app.updateRepo(result),
      success: (_) => 'Saved',
    );
  }
}

class _RepoSettingsDialog extends StatefulWidget {
  const _RepoSettingsDialog({required this.entry, required this.defaults});
  final RepoEntry entry;
  final AppSettings defaults;

  @override
  State<_RepoSettingsDialog> createState() => _RepoSettingsDialogState();
}

class _RepoSettingsDialogState extends State<_RepoSettingsDialog> {
  late final _name = TextEditingController(text: widget.entry.name);
  late PullStrategy? _pull = widget.entry.pullStrategy;
  late bool? _push = widget.entry.pushAfterCommit;
  late bool _autoFetch = widget.entry.autoFetch;

  @override
  Widget build(BuildContext context) {
    final d = widget.defaults;
    return AlertDialog(
      title: const Text('Repository settings'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Display name'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<PullStrategy?>(
              initialValue: _pull,
              decoration: const InputDecoration(labelText: 'Pull strategy'),
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text('Default (${pullStrategyLabel(d.pullStrategy)})'),
                ),
                for (final p in PullStrategy.values)
                  DropdownMenuItem(value: p, child: Text(pullStrategyLabel(p))),
              ],
              onChanged: (v) => setState(() => _pull = v),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<bool?>(
              initialValue: _push,
              decoration: const InputDecoration(labelText: 'After commit'),
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text(
                    'Default (${d.pushAfterCommit ? 'push automatically' : 'push manually'})',
                  ),
                ),
                const DropdownMenuItem(
                  value: true,
                  child: Text('Push automatically'),
                ),
                const DropdownMenuItem(
                  value: false,
                  child: Text('Push manually'),
                ),
              ],
              onChanged: (v) => setState(() => _push = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Include in auto fetch'),
              value: _autoFetch,
              onChanged: (v) => setState(() => _autoFetch = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            RepoEntry(
              path: widget.entry.path,
              name: _name.text.trim().isEmpty
                  ? widget.entry.name
                  : _name.text.trim(),
              pullStrategy: _pull,
              pushAfterCommit: _push,
              autoFetch: _autoFetch,
            ),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
