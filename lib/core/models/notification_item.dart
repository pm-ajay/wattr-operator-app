enum NotificationType { powerDown, overvoltage, undervoltage, overload, dryRun, reversePhase, restored }

extension NotificationTypeX on NotificationType {
  String get label => switch (this) {
        NotificationType.powerDown => 'Power Down',
        NotificationType.overvoltage => 'Overvoltage',
        NotificationType.undervoltage => 'Undervoltage',
        NotificationType.overload => 'Overload',
        NotificationType.dryRun => 'Dry Run',
        NotificationType.reversePhase => 'Reverse Phase',
        NotificationType.restored => 'Power Restored',
      };
}

class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.type,
    required this.pumpId,
    required this.pumpName,
    required this.sectorName,
    required this.message,
    required this.timestamp,
    this.read = false,
  });

  final String id;
  final NotificationType type;
  final String pumpId;
  final String pumpName;
  final String sectorName;
  final String message;
  final DateTime timestamp;
  final bool read;

  NotificationItem copyWith({bool? read}) {
    return NotificationItem(
      id: id,
      type: type,
      pumpId: pumpId,
      pumpName: pumpName,
      sectorName: sectorName,
      message: message,
      timestamp: timestamp,
      read: read ?? this.read,
    );
  }
}
