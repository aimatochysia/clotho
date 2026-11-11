import 'package:flutter/material.dart';

import '../../core/git_service.dart';

/// Unified diff with line numbers and colored additions/removals.
class DiffView extends StatelessWidget {
  const DiffView({
    super.key,
    required this.diff,
    this.shrinkWrap = false,
    this.binary,
  });

  final FileDiff diff;

  /// Shown instead of the text diff for binary files (an image preview).
  final Widget? binary;

  /// True when embedded inside another scroll view (commit details).
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (diff.isBinary) {
      final b = binary;
      if (b != null) {
        return shrinkWrap ? b : SingleChildScrollView(child: b);
      }
      return const _Notice(
        icon: Icons.memory,
        text: 'Binary file; no text diff to show.',
      );
    }
    if (diff.hunks.isEmpty) {
      return const _Notice(icon: Icons.check, text: 'No differences.');
    }
    final addBg = dark ? const Color(0xFF12361F) : const Color(0xFFE6FFEC);
    final delBg = dark ? const Color(0xFF4A1A1E) : const Color(0xFFFFEBE9);
    final hunkBg = scheme.surfaceContainerHighest;
    const mono = TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.35);
    final numStyle = mono.copyWith(color: scheme.outline);

    final rows = <Widget>[];
    for (final h in diff.hunks) {
      rows.add(
        Container(
          color: hunkBg,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Text(h.header, style: mono.copyWith(color: scheme.primary)),
        ),
      );
      for (final l in h.lines) {
        final (bg, sign) = switch (l.kind) {
          LineKind.added => (addBg, '+'),
          LineKind.removed => (delBg, '-'),
          LineKind.context => (Colors.transparent, ' '),
        };
        rows.add(
          Container(
            color: bg,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 48,
                  child: Text(
                    '${l.oldLineno ?? ''}',
                    textAlign: TextAlign.right,
                    style: numStyle,
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    '${l.newLineno ?? ''}',
                    textAlign: TextAlign.right,
                    style: numStyle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$sign ${l.content.replaceAll('\t', '    ')}',
                  style: mono,
                  softWrap: false,
                ),
              ],
            ),
          ),
        );
      }
    }
    if (diff.truncated) {
      rows.add(
        const _Notice(
          icon: Icons.content_cut,
          text: 'Diff is very large; the rest is hidden.',
        ),
      );
    }

    final body = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 600),
        child: IntrinsicWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rows,
          ),
        ),
      ),
    );
    if (shrinkWrap) return SelectionArea(child: body);
    return SelectionArea(child: SingleChildScrollView(child: body));
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Flexible(child: Text(text)),
      ],
    ),
  );
}

/// "+12 −3" summary.
class DiffStat extends StatelessWidget {
  const DiffStat({super.key, required this.additions, required this.deletions});
  final int additions;
  final int deletions;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        '+$additions',
        style: const TextStyle(
          color: Color(0xFF1A7F37),
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(width: 6),
      Text(
        '−$deletions',
        style: const TextStyle(
          color: Color(0xFFCF222E),
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}
