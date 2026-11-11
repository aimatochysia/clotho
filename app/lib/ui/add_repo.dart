import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_controller.dart';
import 'widgets/feedback.dart';

/// Asks for a folder: the system picker on desktop, a typed path on Android
/// (the Android picker returns content URIs that Git cannot open).
Future<String?> pickFolder(
  BuildContext context, {
  required String title,
}) async {
  if (Platform.isAndroid) {
    final granted = await _ensureAndroidStorage(context);
    if (!granted || !context.mounted) return null;
    return promptText(
      context,
      title: title,
      label: 'Folder path',
      hint: '/storage/emulated/0/projects',
      action: 'Choose',
    );
  }
  return getDirectoryPath(confirmButtonText: 'Choose');
}

const _storage = MethodChannel('clotho/storage');

Future<bool> _hasAllFilesAccess() async =>
    await _storage.invokeMethod<bool>('hasAllFilesAccess') ?? false;

Future<bool> _ensureAndroidStorage(BuildContext context) async {
  if (await _hasAllFilesAccess()) return true;
  if (!context.mounted) return false;
  final ok = await confirm(
    context,
    title: 'Allow access to your files',
    message:
        'Clotho needs "All files access" to open repositories in any folder. '
        'Android will open its settings page; turn the switch on, then come back.',
    action: 'Open settings',
  );
  if (!ok) return false;
  await _storage.invokeMethod<void>('requestAllFilesAccess');
  // The settings screen returns asynchronously; wait until the app is in
  // front again, then check.
  final ready = Completer<void>();
  final listener = AppLifecycleListener(
    onResume: () {
      if (!ready.isCompleted) ready.complete();
    },
  );
  await ready.future.timeout(const Duration(minutes: 5), onTimeout: () {});
  listener.dispose();
  return _hasAllFilesAccess();
}

Future<void> addRepository(BuildContext context, AppController app) async {
  final path = await pickFolder(context, title: 'Add repository');
  if (path == null || path.isEmpty || !context.mounted) return;
  await guarded(context, () async {
    final report = await app.addRepos([path]);
    if (report.added.isEmpty && context.mounted) {
      final reason = report.skipped.isNotEmpty
          ? report.skipped.first.reason
          : 'unknown reason';
      showMessage(context, 'Not added: $reason', error: true);
    }
  });
}

/// Scans a folder for repositories and lets the person pick which to add.
Future<void> scanFolder(BuildContext context, AppController app) async {
  final root = await pickFolder(context, title: 'Scan folder for repositories');
  if (root == null || root.isEmpty || !context.mounted) return;
  final found = await guarded(context, () => app.scan(root));
  if (found == null || !context.mounted) return;
  final known = {for (final r in app.repos) r.entry.path};
  final candidates = found.where((p) => !known.contains(p)).toList();
  if (candidates.isEmpty) {
    showMessage(
      context,
      found.isEmpty
          ? 'No repositories found in $root'
          : 'All repositories there are already added',
    );
    return;
  }
  final chosen = await showDialog<List<String>>(
    context: context,
    builder: (ctx) => _ScanResultDialog(root: root, paths: candidates),
  );
  if (chosen == null || chosen.isEmpty || !context.mounted) return;
  await guarded(
    context,
    () => app.addRepos(chosen),
    success: (r) =>
        'Added ${r.added.length} repositor${r.added.length == 1 ? 'y' : 'ies'}',
  );
}

class _ScanResultDialog extends StatefulWidget {
  const _ScanResultDialog({required this.root, required this.paths});
  final String root;
  final List<String> paths;

  @override
  State<_ScanResultDialog> createState() => _ScanResultDialogState();
}

class _ScanResultDialogState extends State<_ScanResultDialog> {
  late final Set<String> _selected = widget.paths.toSet();

  String _short(String p) {
    final r = widget.root.endsWith(Platform.pathSeparator)
        ? widget.root
        : '${widget.root}${Platform.pathSeparator}';
    return p.startsWith(r) ? p.substring(r.length) : p;
  }

  @override
  Widget build(BuildContext context) {
    final all = _selected.length == widget.paths.length;
    return AlertDialog(
      title: Text(
        'Found ${widget.paths.length} repositor${widget.paths.length == 1 ? 'y' : 'ies'}',
      ),
      content: SizedBox(
        width: 480,
        height: 400,
        child: Column(
          children: [
            CheckboxListTile(
              title: const Text('Select all'),
              value: all,
              onChanged: (v) => setState(() {
                _selected
                  ..clear()
                  ..addAll(v == true ? widget.paths : const []);
              }),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                children: [
                  for (final p in widget.paths)
                    CheckboxListTile(
                      dense: true,
                      title: Text(_short(p)),
                      value: _selected.contains(p),
                      onChanged: (v) => setState(
                        () =>
                            v == true ? _selected.add(p) : _selected.remove(p),
                      ),
                    ),
                ],
              ),
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
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.pop(context, _selected.toList()..sort()),
          child: Text('Add ${_selected.length}'),
        ),
      ],
    );
  }
}
