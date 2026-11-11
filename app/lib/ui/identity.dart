import 'package:flutter/material.dart';

import '../core/errors.dart';
import '../core/git_service.dart';
import '../src/rust/error.dart';
import '../state/app_controller.dart';
import '../state/github_scope.dart';
import 'widgets/feedback.dart';

/// Runs [op] like [guarded]. When Git does not know who to commit as, asks
/// for a name and email once, saves them as the default identity and retries.
Future<T?> withIdentity<T>(
  BuildContext context,
  AppController app,
  Future<T> Function() op, {
  String Function(T result)? success,
}) async {
  try {
    final r = await op();
    if (context.mounted && success != null) showMessage(context, success(r));
    return r;
  } on CoreError_MissingIdentity {
    if (!context.mounted) return null;
    final id = await showIdentityDialog(
      context,
      title: 'Who is committing?',
      intro:
          'Git records a name and email with every commit. They are saved in '
          'Clotho and can be changed or extended in Settings.',
      initial: _suggestion(context),
    );
    if (id == null || !context.mounted) return null;
    try {
      await app.saveIdentity(id, makeDefault: true);
    } catch (e) {
      if (context.mounted) showMessage(context, describeError(e), error: true);
      return null;
    }
    if (!context.mounted) return null;
    return guarded(context, op, success: success);
  } catch (e) {
    if (context.mounted) showMessage(context, describeError(e), error: true);
    return null;
  }
}

/// Prefills the dialog from the signed-in GitHub account, using GitHub's
/// private no-reply address so the real email stays hidden.
Identity? _suggestion(BuildContext context) {
  final scope = context.getInheritedWidgetOfExactType<GitHubScope>();
  final user = scope?.auth.user;
  if (user == null) return null;
  return Identity(
    name: (user.name?.trim().isNotEmpty ?? false)
        ? user.name!.trim()
        : user.login,
    email: '${user.login}@users.noreply.github.com',
  );
}

Future<Identity?> showIdentityDialog(
  BuildContext context, {
  String title = 'Commit identity',
  String? intro,
  Identity? initial,
}) => showDialog<Identity>(
  context: context,
  builder: (_) => _IdentityDialog(title: title, intro: intro, initial: initial),
);

class _IdentityDialog extends StatefulWidget {
  const _IdentityDialog({required this.title, this.intro, this.initial});
  final String title;
  final String? intro;
  final Identity? initial;

  @override
  State<_IdentityDialog> createState() => _IdentityDialogState();
}

class _IdentityDialogState extends State<_IdentityDialog> {
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _email = TextEditingController(text: widget.initial?.email);
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  static String? _checkEmail(String? v) {
    final e = (v ?? '').trim();
    final at = e.indexOf('@');
    if (at <= 0 || at == e.length - 1 || e.contains(' ')) {
      return 'Enter an email address';
    }
    return null;
  }

  void _save() {
    if (!(_form.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      Identity(name: _name.text.trim(), email: _email.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.intro != null) ...[
                Text(widget.intro!),
                const SizedBox(height: 16),
              ],
              TextFormField(
                key: const Key('identity-name'),
                controller: _name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Enter a name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('identity-email'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  helperText: 'Use the email of your GitHub account so commits link to you.',
                  helperMaxLines: 2,
                ),
                validator: _checkEmail,
                onFieldSubmitted: (_) => _save(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

/// Settings section: the identities to commit as, with the default marked.
class IdentitySettings extends StatelessWidget {
  const IdentitySettings({super.key, required this.app});
  final AppController app;

  @override
  Widget build(BuildContext context) {
    final s = app.settings;
    final ids = s.identities;
    Future<void> save(List<Identity> next, int def) => guarded(
      context,
      () => app.updateSettings(
        s.copyWith(identities: next, defaultIdentity: def),
      ),
    );
    return Column(
      children: [
        if (ids.isEmpty)
          FutureBuilder<Identity?>(
            future: app.git.gitIdentity(null),
            builder: (context, snap) => ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: Text(
                snap.data == null
                    ? 'Not set yet'
                    : 'Using Git config: ${snap.data!.label}',
              ),
              subtitle: const Text(
                'Add an identity to choose who commits are made as.',
              ),
            ),
          ),
        for (var i = 0; i < ids.length; i++)
          ListTile(
            key: Key('identity-$i'),
            leading: Icon(
              i == s.defaultIdentity
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
            ),
            title: Text(ids[i].name),
            subtitle: Text(
              '${ids[i].email}${i == s.defaultIdentity ? '  ·  default' : ''}',
            ),
            onTap: () => save(ids, i),
            trailing: PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'edit') {
                  final edited = await showIdentityDialog(
                    context,
                    title: 'Edit identity',
                    initial: ids[i],
                  );
                  if (edited != null) {
                    await save([...ids]..[i] = edited, s.defaultIdentity);
                  }
                } else if (v == 'remove') {
                  final next = [...ids]..removeAt(i);
                  final def = s.defaultIdentity > i
                      ? s.defaultIdentity - 1
                      : s.defaultIdentity;
                  await save(
                    next,
                    def.clamp(0, next.isEmpty ? 0 : next.length - 1),
                  );
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'remove', child: Text('Remove')),
              ],
            ),
          ),
        ListTile(
          key: const Key('add-identity'),
          leading: const Icon(Icons.person_add_alt),
          title: const Text('Add identity'),
          onTap: () async {
            final fromGit = ids.isEmpty
                ? await app.git.gitIdentity(null)
                : null;
            if (!context.mounted) return;
            final id = await showIdentityDialog(
              context,
              title: 'Add identity',
              initial: fromGit,
            );
            if (id != null && context.mounted) {
              await guarded(context, () => app.saveIdentity(id));
            }
          },
        ),
      ],
    );
  }
}
