import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/errors.dart';
import '../../core/format.dart';
import '../../core/git_service.dart';
import '../../core/github_service.dart';
import '../../state/app_controller.dart';
import '../../state/github_scope.dart';
import '../add_repo.dart' show pickFolder;
import '../widgets/feedback.dart';

/// Folder name Git would pick for [url]: the last path part without `.git`.
String repoNameFromUrl(String url) {
  var s = url.trim().replaceAll(RegExp(r'[/\\]+$'), '');
  final cut = s.lastIndexOf(RegExp(r'[/:\\]'));
  if (cut >= 0) s = s.substring(cut + 1);
  if (s.endsWith('.git')) s = s.substring(0, s.length - 4);
  return s;
}

/// Asks where to clone [url] (or asks for a URL too), clones it with a
/// progress dialog and adds the result to the dashboard. Returns the path.
Future<String?> cloneRepository(
  BuildContext context,
  AppController app, {
  String? url,
}) async {
  final scope = GitHubScope.of(context);
  final req = await showDialog<_CloneRequest>(
    context: context,
    builder: (_) => _CloneDialog(app: app, initialUrl: url),
  );
  if (req == null || !context.mounted) return null;
  final path = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _CloneProgressDialog(
      stream: scope.github.clone(req.url, req.dest, scope.auth.token),
      name: repoNameFromUrl(req.url),
    ),
  );
  if (path == null || !context.mounted) return null;
  await guarded(context, () async {
    if (app.settings.cloneDir != req.parent) {
      await app.updateSettings(app.settings.copyWith(cloneDir: req.parent));
    }
    await app.addRepos([path]);
  }, success: (_) => 'Cloned ${repoNameFromUrl(req.url)}');
  return path;
}

class _CloneRequest {
  const _CloneRequest(this.url, this.parent, this.name);
  final String url;
  final String parent;
  final String name;
  String get dest => '$parent${Platform.pathSeparator}$name';
}

class _CloneDialog extends StatefulWidget {
  const _CloneDialog({required this.app, this.initialUrl});
  final AppController app;
  final String? initialUrl;

  @override
  State<_CloneDialog> createState() => _CloneDialogState();
}

class _CloneDialogState extends State<_CloneDialog> {
  late final _url = TextEditingController(text: widget.initialUrl ?? '');
  late final _name = TextEditingController(
    text: repoNameFromUrl(widget.initialUrl ?? ''),
  );
  late String? _parent = widget.app.settings.cloneDir;
  bool _nameEdited = false;

  @override
  void dispose() {
    _url.dispose();
    _name.dispose();
    super.dispose();
  }

  String? get _problem {
    if (_url.text.trim().isEmpty) return 'Enter the repository URL';
    if (_parent == null) return 'Choose a folder';
    final n = _name.text.trim();
    if (n.isEmpty || n == '.' || n == '..' || n.contains(RegExp(r'[/\\]'))) {
      return 'Enter a folder name';
    }
    final dest = Directory('$_parent${Platform.pathSeparator}$n');
    if (dest.existsSync() && dest.listSync().isNotEmpty) {
      return 'That folder already exists and is not empty';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final problem = _problem;
    final fixedUrl = widget.initialUrl != null;
    return AlertDialog(
      title: Text(
        fixedUrl ? 'Clone ${repoNameFromUrl(widget.initialUrl!)}' : 'Clone',
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('clone-url'),
              controller: _url,
              readOnly: fixedUrl,
              autofocus: !fixedUrl,
              decoration: const InputDecoration(
                labelText: 'Repository URL',
                hintText: 'https://github.com/owner/name.git',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() {
                if (!_nameEdited) _name.text = repoNameFromUrl(v);
              }),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.folder_outlined),
              title: Text(_parent ?? 'No folder chosen'),
              subtitle: const Text('Clone into'),
              trailing: OutlinedButton(
                key: const Key('clone-pick'),
                onPressed: () async {
                  final p = await pickFolder(context, title: 'Clone into');
                  if (p != null && p.isNotEmpty) setState(() => _parent = p);
                },
                child: const Text('Choose…'),
              ),
            ),
            TextField(
              key: const Key('clone-name'),
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Folder name',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() => _nameEdited = true),
            ),
            if (problem != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  problem,
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
          key: const Key('clone-start'),
          onPressed: problem != null
              ? null
              : () => Navigator.pop(
                  context,
                  _CloneRequest(_url.text.trim(), _parent!, _name.text.trim()),
                ),
          child: const Text('Clone'),
        ),
      ],
    );
  }
}

class _CloneProgressDialog extends StatefulWidget {
  const _CloneProgressDialog({required this.stream, required this.name});
  final Stream<CloneProgress> stream;
  final String name;

  @override
  State<_CloneProgressDialog> createState() => _CloneProgressDialogState();
}

class _CloneProgressDialogState extends State<_CloneProgressDialog> {
  StreamSubscription<CloneProgress>? _sub;
  CloneProgress? _last;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sub = widget.stream.listen((p) {
      if (!mounted) return;
      if (p is CloneProgress_Done) {
        Navigator.of(context).pop(p.path);
        return;
      }
      setState(() => _last = p);
    }, onError: (Object e) => setState(() => _error = describeError(e)));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  (String, double?) get _progress => switch (_last) {
    null => ('Connecting…', null),
    CloneProgress_Receiving(
      :final receivedObjects,
      :final totalObjects,
      :final receivedBytes,
    ) =>
      (
        'Receiving objects $receivedObjects/$totalObjects '
            '(${formatBytes(receivedBytes.toInt())})',
        totalObjects == 0 ? null : receivedObjects / totalObjects,
      ),
    CloneProgress_Resolving(:final indexedDeltas, :final totalDeltas) => (
      'Resolving deltas $indexedDeltas/$totalDeltas',
      totalDeltas == 0 ? null : indexedDeltas / totalDeltas,
    ),
    CloneProgress_CheckingOut(:final done, :final total) => (
      'Checking out files $done/$total',
      total == 0 ? null : done / total,
    ),
    CloneProgress_Done() => ('Done', 1.0),
  };

  @override
  Widget build(BuildContext context) {
    final (label, value) = _progress;
    return AlertDialog(
      title: Text('Cloning ${widget.name}'),
      content: SizedBox(
        width: 420,
        child: _error != null
            ? Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(value: value),
                  const SizedBox(height: 12),
                  Text(label),
                ],
              ),
      ),
      actions: [
        if (_error != null)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
      ],
    );
  }
}
