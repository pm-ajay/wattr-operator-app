import 'package:flutter/material.dart';

/// Selection only — no real device permission APIs are wired up. Statuses
/// below are fixed dummy values standing in for what a real permission
/// check would report, so the entry point exists ahead of real wiring.
class _PermissionInfo {
  const _PermissionInfo({required this.label, required this.description, required this.enabled});

  final String label;
  final String description;
  final bool enabled;
}

const _permissions = [
  _PermissionInfo(
    label: 'Notifications',
    description: 'Alerts for faults, power loss, and schedule activity.',
    enabled: true,
  ),
  _PermissionInfo(
    label: 'Location',
    description: 'Used to confirm you\'re on-site for certain actions.',
    enabled: false,
  ),
  _PermissionInfo(
    label: 'Background Activity',
    description: 'Keeps pump status updates flowing while the app is closed.',
    enabled: true,
  ),
];

class PermissionsScreen extends StatelessWidget {
  const PermissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('App Permissions')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final permission in _permissions)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                title: Text(permission.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(permission.description),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: permission.enabled
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    permission.enabled ? 'Enabled' : 'Disabled',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: permission.enabled
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      permission.enabled
                          ? '${permission.label} is enabled.'
                          : 'Would open your device\'s app settings to enable ${permission.label}.',
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
