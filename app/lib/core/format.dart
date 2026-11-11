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
