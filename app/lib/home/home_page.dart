import 'package:flutter/material.dart';

import 'repo_inspector.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.coreVersion,
    required this.libgit2Version,
    required this.inspector,
  });

  final String coreVersion;
  final String libgit2Version;
  final RepoInspector inspector;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _pathController = TextEditingController();
  InspectResult? _result;
  bool _busy = false;

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _inspect() async {
    final path = _pathController.text.trim();
    if (path.isEmpty) return;
    setState(() => _busy = true);
    final result = await widget.inspector.inspect(path);
    if (!mounted) return;
    setState(() {
      _result = result;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Clotho')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text('Open a repository', style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('path-field'),
                      controller: _pathController,
                      decoration: const InputDecoration(
                        labelText: 'Folder path',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _inspect(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    key: const Key('inspect-button'),
                    onPressed: _busy ? null : _inspect,
                    child: const Text('Inspect'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_busy) const LinearProgressIndicator(),
              if (_result case final result?) _ResultCard(result: result),
              const SizedBox(height: 32),
              Text(
                'Core ${widget.coreVersion} · libgit2 ${widget.libgit2Version}',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final InspectResult result;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return switch (result) {
      InspectFound(:final info) => Card(
        child: ListTile(
          leading: const Icon(Icons.source),
          title: Text(info.path),
          subtitle: Text(
            [
              'Branch: ${info.branch ?? 'detached HEAD'}',
              if (info.isEmpty) 'no commits yet',
              if (info.isBare) 'bare',
            ].join(' · '),
          ),
        ),
      ),
      InspectFailed(:final message) => Card(
        color: colors.errorContainer,
        child: ListTile(
          leading: Icon(Icons.error_outline, color: colors.onErrorContainer),
          title: Text(
            message,
            style: TextStyle(color: colors.onErrorContainer),
          ),
        ),
      ),
    };
  }
}
