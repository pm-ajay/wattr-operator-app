String formatDurationShort(Duration d) {
  final totalMinutes = d.inMinutes;
  final h = totalMinutes ~/ 60;
  final m = totalMinutes % 60;
  if (h == 0) return '${m}m';
  return '${h}h ${m}m';
}
