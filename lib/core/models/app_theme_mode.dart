enum AppThemeMode { system, light, dark }

extension AppThemeModeX on AppThemeMode {
  String get label => switch (this) {
        AppThemeMode.system => 'System Default',
        AppThemeMode.light => 'Light',
        AppThemeMode.dark => 'Dark',
      };

  String get description => switch (this) {
        AppThemeMode.system => 'Match your device\'s display setting.',
        AppThemeMode.light => 'Always use the light theme.',
        AppThemeMode.dark => 'Always use the dark theme.',
      };
}
