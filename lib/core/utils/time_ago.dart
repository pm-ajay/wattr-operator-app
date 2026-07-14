String timeAgo(DateTime from, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final diff = reference.difference(from);
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} hr ago';
  return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
}
