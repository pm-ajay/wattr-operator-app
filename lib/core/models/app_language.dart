enum AppLanguage { english, hindi, punjabi }

extension AppLanguageX on AppLanguage {
  String get nativeName => switch (this) {
        AppLanguage.english => 'English',
        AppLanguage.hindi => 'हिंदी',
        AppLanguage.punjabi => 'ਪੰਜਾਬੀ',
      };

  String get englishName => switch (this) {
        AppLanguage.english => 'English',
        AppLanguage.hindi => 'Hindi',
        AppLanguage.punjabi => 'Punjabi',
      };
}
