import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dummy_data/providers.dart';
import '../../core/models/app_language.dart';

/// UI entry point only — selecting a language does not yet change any
/// on-screen text. Full translation is tracked as separate follow-up work.
class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selected = ref.watch(preferredLanguageProvider);
    final notifier = ref.read(preferredLanguageProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Language')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Choose the language you\'re most comfortable reading the app in.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                for (final language in AppLanguage.values)
                  RadioListTile<AppLanguage>(
                    title: Text(language.nativeName),
                    subtitle: language == AppLanguage.english ? null : Text(language.englishName),
                    value: language,
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
}
