import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../core/update_service.dart';
import '../state/update_controller.dart';
import '../state/update_scope.dart';
import 'github/sign_in.dart' show openUrl;
import 'widgets/feedback.dart';

/// "Clotho X is available" card at the top of the dashboard.
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final updates = UpdateScope.maybeOf(context);
    if (updates == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: updates,
      builder: (context, _) {
        final u = updates.available;
        if (!updates.showBanner || u == null) return const SizedBox.shrink();
        final scheme = Theme.of(context).colorScheme;
        return Card(
          key: const Key('update-banner'),
          color: scheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                const Icon(Icons.system_update),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Clotho ${u.version} is available '
                    '(you have ${updates.currentVersion}).',
                  ),
                ),
                TextButton(
                  onPressed: updates.dismiss,
                  child: const Text('Later'),
                ),
                FilledButton.tonal(
                  key: const Key('update-view'),
                  onPressed: () => showUpdateDialog(context, updates),
                  child: const Text('View'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Settings tile: current version and a "check now" button.
class UpdateTile extends StatelessWidget {
  const UpdateTile({super.key});

  @override
  Widget build(BuildContext context) {
    final updates = UpdateScope.maybeOf(context);
    if (updates == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: updates,
      builder: (context, _) {
        final u = updates.available;
        final checking = updates.phase == UpdatePhase.checking;
        return ListTile(
          leading: const Icon(Icons.info_outline),
          title: Text('Clotho ${updates.currentVersion}'),
          subtitle: Text(
            u != null
                ? 'Version ${u.version} is available.'
                : updates.lastChecked != null
                ? 'Up to date.'
                : 'Not checked yet.',
          ),
          trailing: checking
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : TextButton(
                  key: const Key('update-check'),
                  onPressed: () async {
                    final found = await guarded(context, () => updates.check());
                    if (!context.mounted) return;
                    if (found != null) {
                      await showUpdateDialog(context, updates);
                    } else if (updates.error == null) {
                      showMessage(context, 'Clotho is up to date');
                    }
                  },
                  child: Text(u != null ? 'View' : 'Check now'),
                ),
        );
      },
    );
  }
}

Future<void> showUpdateDialog(BuildContext context, UpdateController updates) =>
    showDialog<void>(
      context: context,
      builder: (_) => UpdateDialog(updates: updates),
    );

class UpdateDialog extends StatelessWidget {
  const UpdateDialog({super.key, required this.updates});
  final UpdateController updates;

  Future<void> _install(BuildContext context) async {
    try {
      final r = await updates.install();
      if (!context.mounted) return;
      switch (r) {
        case InstallResult.started:
          if (updates.package == PackageKind.windowsInstaller) {
            // Let the installer replace files that this process holds open.
            exit(0);
          }
          Navigator.pop(context);
        case InstallResult.needsPermission:
          showMessage(
            context,
            'Allow Clotho to install apps, come back, then press Install again.',
          );
        case InstallResult.manual:
          break;
      }
    } catch (e) {
      if (context.mounted) {
        showMessage(context, 'Could not start the installer: $e', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: updates,
      builder: (context, _) {
        final u = updates.available;
        final theme = Theme.of(context);
        if (u == null) {
          return AlertDialog(
            title: const Text('No update'),
            content: const Text('Clotho is up to date.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        }
        final phase = updates.phase;
        final busy =
            phase == UpdatePhase.downloading || phase == UpdatePhase.verifying;
        final manual = switch (updates.package) {
          PackageKind.deb ||
          PackageKind.arch ||
          PackageKind.tarball ||
          PackageKind.windowsZip ||
          PackageKind.unknown => true,
          _ => false,
        };
        final hint = updates.path == null
            ? null
            : manualInstallHint(updates.package, updates.path!);
        return AlertDialog(
          title: Text(u.name),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [
                    'You have ${updates.currentVersion}',
                    if (u.publishedAt != null)
                      'released ${relativeIso(u.publishedAt)}',
                    if (u.asset != null) formatBytes(u.asset!.size.toInt()),
                  ].join(' · '),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 280),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        u.notes.trim().isEmpty
                            ? 'No release notes.'
                            : u.notes.trim(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (!updates.canDownload)
                  const Text(
                    'This release has no package for your system. Download it '
                    'from the release page instead.',
                  ),
                if (busy) ...[
                  LinearProgressIndicator(
                    value: phase == UpdatePhase.verifying
                        ? null
                        : updates.progress,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    phase == UpdatePhase.verifying
                        ? 'Verifying signature and checksum…'
                        : 'Downloading…',
                  ),
                ],
                if (phase == UpdatePhase.failed && updates.error != null)
                  Text(
                    updates.error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                if (phase == UpdatePhase.ready) ...[
                  Row(
                    children: [
                      const Icon(Icons.verified, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Signature and SHA-256 verified'
                          '${updates.sha256 == null ? '' : ' (${updates.sha256!.substring(0, 12)}…)'}',
                        ),
                      ),
                    ],
                  ),
                  if (manual && hint != null) ...[
                    const SizedBox(height: 8),
                    const Text('Install it with:'),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            hint,
                            key: const Key('update-hint'),
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Copy',
                          icon: const Icon(Icons.copy, size: 18),
                          onPressed: () =>
                              Clipboard.setData(ClipboardData(text: hint)),
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => openUrl(context, u.htmlUrl),
              child: const Text('Release page'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(busy ? 'Hide' : 'Close'),
            ),
            if (phase == UpdatePhase.ready) ...[
              if (!Platform.isAndroid)
                TextButton(
                  onPressed: updates.reveal,
                  child: const Text('Show file'),
                ),
              if (!manual)
                FilledButton(
                  key: const Key('update-install'),
                  onPressed: () => _install(context),
                  child: const Text('Install'),
                ),
            ] else if (updates.canDownload)
              FilledButton(
                key: const Key('update-download'),
                onPressed: busy ? null : updates.download,
                child: const Text('Download'),
              ),
          ],
        );
      },
    );
  }
}
