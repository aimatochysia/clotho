import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/errors.dart';
import '../../state/auth_controller.dart';
import '../../state/github_scope.dart';
import '../widgets/feedback.dart';

/// Opens [url] in the system browser, reporting failures in a snackbar.
Future<void> openUrl(BuildContext context, String url) async {
  final ok = await launchUrl(
    Uri.parse(url),
    mode: LaunchMode.externalApplication,
  ).catchError((_) => false);
  if (!ok && context.mounted) {
    showMessage(context, 'Could not open $url', error: true);
  }
}

const _newTokenUrl =
    'https://github.com/settings/tokens/new?scopes=repo,read:user,workflow&description=Clotho';

/// App-bar button: the avatar when signed in, a sign-in icon otherwise.
class AccountButton extends StatelessWidget {
  const AccountButton({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = GitHubScope.of(context).auth;
    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) {
        final user = auth.user;
        if (!auth.signedIn) {
          return IconButton(
            key: const Key('sign-in'),
            tooltip: 'Sign in to GitHub',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => showSignIn(context),
          );
        }
        return PopupMenuButton<String>(
          key: const Key('account'),
          tooltip: user == null
              ? 'GitHub account'
              : 'Signed in as ${user.login}',
          icon: user == null
              ? const Icon(Icons.account_circle)
              : CircleAvatar(
                  radius: 14,
                  backgroundImage: NetworkImage(user.avatarUrl),
                  onBackgroundImageError: (_, _) {},
                ),
          onSelected: (v) async {
            switch (v) {
              case 'profile':
                if (user != null) await openUrl(context, user.htmlUrl);
              case 'signout':
                final ok = await confirm(
                  context,
                  title: 'Sign out of GitHub?',
                  message:
                      'Clotho forgets the token. To revoke it completely, also '
                      'remove it on GitHub under Settings › Applications.',
                  action: 'Sign out',
                );
                if (ok) await auth.signOut();
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              enabled: false,
              child: Text(
                user == null
                    ? 'Signed in (offline)'
                    : 'Signed in as ${user.name ?? user.login}',
              ),
            ),
            if (user != null)
              const PopupMenuItem(
                value: 'profile',
                child: Text('Open profile on GitHub'),
              ),
            const PopupMenuItem(value: 'signout', child: Text('Sign out')),
          ],
        );
      },
    );
  }
}

/// Shows the sign-in dialog. Completes with true once signed in.
Future<bool> showSignIn(BuildContext context) async {
  final auth = GitHubScope.of(context).auth;
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => SignInDialog(auth: auth),
  );
  auth.cancelDeviceSignIn();
  if (ok == true && context.mounted) {
    final w = auth.storageWarning;
    showMessage(
      context,
      w ?? 'Signed in as ${auth.user?.login ?? 'GitHub user'}',
      error: w != null,
    );
  }
  return ok == true;
}

class SignInDialog extends StatefulWidget {
  const SignInDialog({super.key, required this.auth});
  final AuthController auth;

  @override
  State<SignInDialog> createState() => _SignInDialogState();
}

class _SignInDialogState extends State<SignInDialog> {
  late bool _usePat = !widget.auth.deviceFlowAvailable;
  final _pat = TextEditingController();
  bool _working = false;
  String? _error;

  AuthController get auth => widget.auth;

  @override
  void initState() {
    super.initState();
    auth.addListener(_onAuth);
  }

  @override
  void dispose() {
    auth.removeListener(_onAuth);
    _pat.dispose();
    super.dispose();
  }

  void _onAuth() {
    if (!mounted) return;
    if (auth.signedIn && auth.pending == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      if (auth.pending == null && auth.signInError != null) {
        _error = auth.signInError;
      }
    });
  }

  Future<void> _startBrowser() async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final code = await auth.startDeviceSignIn();
      await Clipboard.setData(ClipboardData(text: code.userCode));
      if (mounted) await openUrl(context, code.verificationUri);
    } catch (e) {
      _error = describeError(e);
    }
    if (mounted) setState(() => _working = false);
  }

  Future<void> _submitPat() async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await auth.signInWithToken(_pat.text);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = describeError(e);
          _working = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = auth.pending;
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Sign in to GitHub'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (auth.deviceFlowAvailable)
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Browser')),
                  ButtonSegment(value: true, label: Text('Access token')),
                ],
                selected: {_usePat},
                onSelectionChanged: (v) {
                  auth.cancelDeviceSignIn();
                  setState(() {
                    _usePat = v.first;
                    _error = null;
                  });
                },
              ),
            const SizedBox(height: 16),
            if (!_usePat && pending == null)
              const Text(
                'Clotho opens github.com in your browser. Enter the code it shows '
                'you there and approve access.',
              ),
            if (!_usePat && pending != null) ...[
              const Text(
                'Enter this code on GitHub (it is on your clipboard):',
              ),
              const SizedBox(height: 12),
              Center(
                child: SelectableText(
                  pending.code.userCode,
                  key: const Key('device-code'),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontFamily: 'monospace',
                    letterSpacing: 4,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: () => Clipboard.setData(
                      ClipboardData(text: pending.code.userCode),
                    ),
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy'),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        openUrl(context, pending.code.verificationUri),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Open GitHub'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Row(
                children: [
                  SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Waiting for approval…'),
                ],
              ),
            ],
            if (_usePat) ...[
              const Text(
                'Create a classic token with the repo, read:user and workflow '
                'scopes, or a fine-grained token with access to your '
                'repositories, then paste it here.',
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => openUrl(context, _newTokenUrl),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Create a token on GitHub'),
                ),
              ),
              TextField(
                key: const Key('pat-field'),
                controller: _pat,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Personal access token',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _submitPat(),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 8),
            Text(
              'The token is kept in your system keychain and only sent to '
              'github.com.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        if (_usePat)
          FilledButton(
            key: const Key('pat-submit'),
            onPressed: _working ? null : _submitPat,
            child: const Text('Sign in'),
          )
        else if (pending == null)
          FilledButton(
            key: const Key('browser-start'),
            onPressed: _working ? null : _startBrowser,
            child: const Text('Continue in browser'),
          ),
      ],
    );
  }
}
