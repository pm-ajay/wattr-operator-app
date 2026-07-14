enum RunningTimesRange { today, last7, last30 }

extension RunningTimesRangeX on RunningTimesRange {
  String get label => switch (this) {
        RunningTimesRange.today => 'Today',
        RunningTimesRange.last7 => 'Last 7 days',
        RunningTimesRange.last30 => 'Last 30 days',
      };

  DateTime startFrom(DateTime now) => switch (this) {
        RunningTimesRange.today => DateTime(now.year, now.month, now.day),
        RunningTimesRange.last7 => now.subtract(const Duration(days: 7)),
        RunningTimesRange.last30 => now.subtract(const Duration(days: 30)),
      };
}
