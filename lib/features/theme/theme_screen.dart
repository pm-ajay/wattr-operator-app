import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dummy_data/providers.dart';
import '../../core/models/app_theme_mode.dart';

/// UI entry point only — selecting a mode does not yet re-theme the app.
/// Actual light/dark theming is tracked as separate follow-up work.
class ThemeScreen extends ConsumerWidget {
  const ThemeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selected = ref.watch(preferredThemeModeProvider);
    final notifier = ref.read(preferredThemeModeProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Theme')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Choose how Wattr.ai Operator looks on this device.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                for (final mode in AppThemeMode.values)
                  RadioListTile<AppThemeMode>(
                    secondary: Icon(_iconFor(mode)),
                    title: Text(mode.label),
                    subtitle: Text(mode.description),
                    value: mode,
                    groupValue: selected,
                    onChanged: (value) {
                      if (value != null) notifier.select(value);
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(AppThemeMode mode) => switch (mode) {
        AppThemeMode.system => Icons.brightness_auto_outlined,
        AppThemeMode.light => Icons.light_mode_outlined,
        AppThemeMode.dark => Icons.dark_mode_outlined,
      };
}
