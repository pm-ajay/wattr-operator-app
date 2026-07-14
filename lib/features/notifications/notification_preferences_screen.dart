import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dummy_data/providers.dart';
import '../../core/models/notification_item.dart';

class NotificationPreferencesScreen extends ConsumerWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(notificationPreferencesProvider);
    final notifier = ref.read(notificationPreferencesProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Notification Preferences')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Choose which alerts you want to be notified about. All notifications are delivered as push alerts on this device.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                for (final type in NotificationType.values.where((t) => t != NotificationType.restored))
                  SwitchListTile(
                    title: Text(type.label),
                    subtitle: Text(_descriptionFor(type)),
                    value: prefs[type] ?? true,
                    onChanged: (v) => notifier.toggle(type, v),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _descriptionFor(NotificationType type) => switch (type) {
        NotificationType.powerDown => 'Electricity supply to a pump goes down.',
        NotificationType.overvoltage => 'Voltage exceeds the configured safe maximum.',
        NotificationType.undervoltage => 'Voltage drops below the configured safe minimum.',
        NotificationType.overload => 'Current draw exceeds the configured safe maximum.',
        NotificationType.dryRun => 'A pump runs without adequate water flow.',
        NotificationType.reversePhase => 'Incoming phase sequence is reversed.',
        NotificationType.restored => '',
      };
}
