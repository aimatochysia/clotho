import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/git_service.dart';
import '../state/app_controller.dart';
import 'update_ui.dart';
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

String fetchUnitLabel(FetchUnit u, int every) {
  final word = switch (u) {
    FetchUnit.minutes => 'minute',
    FetchUnit.hours => 'hour',
    FetchUnit.days => 'day',
  };
  return every == 1 ? word : '${word}s';
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.app});
  final AppController app;

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
                  onChanged: (p) => save(s.copyWith(pullStrategy: p)),
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
                onChanged: (v) => save(s.copyWith(pushAfterCommit: v)),
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
                  onChanged: (d) => save(s.copyWith(scanDepth: d)),
                ),
              ),
              const _Header('Updates'),
              SwitchListTile(
                secondary: const Icon(Icons.system_update),
                title: const Text('Check for updates on start'),
                value: s.checkUpdates,
                onChanged: (v) => save(s.copyWith(checkUpdates: v)),
              ),
              const UpdateTile(),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Each repository has its own auto fetch schedule and can '
                  'override pull and push settings from its ⋮ menu.',
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
/// and its auto fetch schedule.
Future<void> showRepoSettings(
  BuildContext context,
  AppController app,
  RepoEntry entry,
) async {
  final result = await showDialog<RepoEntry>(
    context: context,
    builder: (_) => _RepoSettingsDialog(
      entry: entry,
      defaults: app.settings,
      backgroundSupported: app.background.supported,
    ),
  );
  if (result == null || !context.mounted) return;
  final turnedOn = result.fetchSchedule.enabled && !entry.fetchSchedule.enabled;
  if (turnedOn) await askAutoFetchPermissions(context, app);
  if (!context.mounted) return;
  await guarded(context, () => app.updateRepo(result), success: (_) => 'Saved');
}

/// Explains, then asks for, what auto fetch needs: notifications for new
/// commits and, on Android, permission to run in the background.
Future<void> askAutoFetchPermissions(
  BuildContext context,
  AppController app,
) async {
  final bg = app.background;
  final needBackground = bg.supported && !await bg.allowed();
  if (!context.mounted) return;
  final go = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.notifications_active_outlined),
      title: const Text('Stay up to date'),
      content: Text(
        needBackground
            ? 'Clotho can tell you when new commits arrive. To fetch while the '
                  'app is closed, Android needs to let Clotho run in the '
                  'background (battery optimisation off). Fetching uses very '
                  'little battery.'
            : 'Clotho can tell you when an automatic fetch finds new commits.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Allow'),
        ),
      ],
    ),
  );
  if (go != true) return;
  await app.notifier.requestPermission();
  if (needBackground) await bg.requestAllowed();
}

class _RepoSettingsDialog extends StatefulWidget {
  const _RepoSettingsDialog({
    required this.entry,
    required this.defaults,
    required this.backgroundSupported,
  });
  final RepoEntry entry;
  final AppSettings defaults;
  final bool backgroundSupported;

  @override
  State<_RepoSettingsDialog> createState() => _RepoSettingsDialogState();
}

class _RepoSettingsDialogState extends State<_RepoSettingsDialog> {
  late final _name = TextEditingController(text: widget.entry.name);
  late PullStrategy? _pull = widget.entry.pullStrategy;
  late bool? _push = widget.entry.pushAfterCommit;
  late bool _autoFetch = widget.entry.fetchSchedule.enabled;
  late FetchUnit _unit = widget.entry.fetchSchedule.unit;
  late final _every = TextEditingController(
    text: '${widget.entry.fetchSchedule.every}',
  );

  int get _everyValue => (int.tryParse(_every.text) ?? 1).clamp(1, 999);

  @override
  void dispose() {
    _name.dispose();
    _every.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.defaults;
    return AlertDialog(
      scrollable: true,
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
              isExpanded: true,
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
              isExpanded: true,
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
            const SizedBox(height: 8),
            SwitchListTile(
              key: const Key('auto-fetch'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Auto fetch'),
              subtitle: Text(
                _autoFetch
                    ? 'Fetches on a schedule and notifies you of new commits.'
                    : 'Off. Fetch by hand from the repository page.',
              ),
              value: _autoFetch,
              onChanged: (v) => setState(() => _autoFetch = v),
            ),
            if (_autoFetch) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 16, right: 12),
                    child: Text('Every'),
                  ),
                  SizedBox(
                    width: 88,
                    child: TextField(
                      key: const Key('auto-fetch-every'),
                      controller: _every,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<FetchUnit>(
                      isExpanded: true,
                      key: const Key('auto-fetch-unit'),
                      initialValue: _unit,
                      items: [
                        for (final u in FetchUnit.values)
                          DropdownMenuItem(
                            value: u,
                            child: Text(fetchUnitLabel(u, _everyValue)),
                          ),
                      ],
                      onChanged: (u) => setState(() => _unit = u ?? _unit),
                    ),
                  ),
                ],
              ),
              if (widget.backgroundSupported &&
                  _unit == FetchUnit.minutes &&
                  _everyValue < 15)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'While Clotho is closed, Android runs background work at '
                    'most every 15 minutes.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
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
              fetchSchedule: FetchSchedule(
                enabled: _autoFetch,
                every: _everyValue,
                unit: _unit,
              ),
              lastAutoFetch: widget.entry.lastAutoFetch,
            ),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
