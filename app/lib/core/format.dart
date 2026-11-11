/// "just now", "5 min ago", "3 h ago", "2 d ago", then a date.
String relativeTime(int epochSeconds, {DateTime? now}) {
  final t = DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000);
  final diff = (now ?? DateTime.now()).difference(t);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays < 30) return '${diff.inDays} d ago';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)}';
}

/// [relativeTime] for an ISO 8601 string from the GitHub API.
String relativeIso(String? iso, {DateTime? now}) {
  final t = iso == null ? null : DateTime.tryParse(iso);
  if (t == null) return '';
  return relativeTime(t.millisecondsSinceEpoch ~/ 1000, now: now);
}

/// "512 B", "2.0 KB", "5.0 MB", "1.20 GB".
String formatBytes(int b) {
  if (b < 1024) return '$b B';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
  if (b < 1024 * 1024 * 1024) {
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}
