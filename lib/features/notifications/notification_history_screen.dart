import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/dummy_data/providers.dart';
import '../../core/models/notification_item.dart';
import '../../core/utils/time_ago.dart';
import '../shell/app_drawer.dart';

class NotificationHistoryScreen extends ConsumerWidget {
  const NotificationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Notification History'),
        actions: [
          if (notifications.any((n) => !n.read))
            TextButton(
              onPressed: () => ref.read(notificationsProvider.notifier).markAllRead(),
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none, size: 40, color: theme.colorScheme.outline),
                  const SizedBox(height: 12),
                  const Text('No notifications yet.'),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: notifications.length,
              separatorBuilder: (context, index) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final n = notifications[index];
                return Card(
                  color: n.read ? null : theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
                  child: ListTile(
                    leading: Icon(_iconFor(n.type), color: _colorFor(n.type, theme)),
                    title: Text(n.message),
                    subtitle: Text('${n.sectorName} · ${timeAgo(n.timestamp)}'),
                    trailing: n.read ? null : const Icon(Icons.circle, size: 8, color: Colors.blue),
                    onTap: () => context.push('/pump/${n.pumpId}'),
                  ),
                );
              },
            ),
    );
  }

  IconData _iconFor(NotificationType type) => switch (type) {
        NotificationType.powerDown => Icons.power_off,
        NotificationType.overvoltage || NotificationType.undervoltage => Icons.bolt,
        NotificationType.overload => Icons.flash_on,
        NotificationType.dryRun => Icons.water_drop_outlined,
        NotificationType.reversePhase => Icons.sync_problem,
        NotificationType.restored => Icons.check_circle_outline,
      };

  Color _colorFor(NotificationType type, ThemeData theme) => switch (type) {
        NotificationType.restored => Colors.green,
        NotificationType.powerDown => Colors.blueGrey,
        _ => theme.colorScheme.error,
      };
}
