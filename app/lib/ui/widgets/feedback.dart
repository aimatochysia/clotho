import 'package:flutter/material.dart';

import '../../core/errors.dart';

void showMessage(BuildContext context, String text, {bool error = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final colors = Theme.of(context).colorScheme;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? colors.error : null,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: error ? 6 : 3),
      ),
    );
}

/// Runs [op], showing [success] (if any) or a readable error afterwards.
Future<T?> guarded<T>(
  BuildContext context,
  Future<T> Function() op, {
  String Function(T result)? success,
}) async {
  try {
    final r = await op();
    if (context.mounted && success != null) showMessage(context, success(r));
    return r;
  } catch (e) {
    if (context.mounted) showMessage(context, describeError(e), error: true);
    return null;
  }
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String action = 'OK',
  bool destructive = false,
}) async {
  final colors = Theme.of(context).colorScheme;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: colors.error)
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok ?? false;
}

Future<String?> promptText(
  BuildContext context, {
  required String title,
  String label = '',
  String initial = '',
  String action = 'OK',
  String? hint,
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        key: const Key('prompt-field'),
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(labelText: label, hintText: hint),
        onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          child: Text(action),
        ),
      ],
    ),
  );
}

/// Small rounded label, used for branch names, ahead/behind counts and refs.
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.icon, this.color, this.tooltip});

  final String text;
  final IconData? icon;
  final Color? color;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = color ?? scheme.secondaryContainer;
    final fg = ThemeData.estimateBrightnessForColor(bg) == Brightness.dark
        ? Colors.white
        : Colors.black87;
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Text(text, style: TextStyle(fontSize: 12, color: fg)),
        ],
      ),
    );
    return tooltip == null ? pill : Tooltip(message: tooltip!, child: pill);
  }
}
