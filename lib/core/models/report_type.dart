enum ReportType { usage, startStop, waterDischarge, fault }

extension ReportTypeX on ReportType {
  String get label => switch (this) {
        ReportType.usage => 'Usage Report',
        ReportType.startStop => 'Start-Stop Report',
        ReportType.waterDischarge => 'Water Discharge Report',
        ReportType.fault => 'Fault Report',
      };
}
