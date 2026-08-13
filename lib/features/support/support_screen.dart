import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const _supportPhoneNumber = '+91 82880 84910';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  Future<void> _call(BuildContext context) async {
    final uri = Uri(scheme: 'tel', path: _supportPhoneNumber.replaceAll(' ', ''));
    final launched = await launchUrl(uri);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the phone dialer on this device.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(Icons.support_agent, color: theme.colorScheme.onPrimaryContainer),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Need help with the app or a pump?',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Call our support line and we\'ll help you sort it out.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _call(context),
                      icon: const Icon(Icons.call),
                      label: const Text(_supportPhoneNumber),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
