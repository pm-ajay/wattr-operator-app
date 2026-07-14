enum SupplyVoltage { v230, v380, v415 }

enum PhaseType { single, three }

extension SupplyVoltageX on SupplyVoltage {
  double get volts => switch (this) {
        SupplyVoltage.v230 => 230,
        SupplyVoltage.v380 => 380,
        SupplyVoltage.v415 => 415,
      };

  String get label => '${volts.toInt()}V';
}

extension PhaseTypeX on PhaseType {
  String get label => switch (this) {
        PhaseType.single => '1-Phase',
        PhaseType.three => '3-Phase',
      };
}

/// Configurable protection thresholds for a single pump, plus the
/// motor inputs used to auto-derive current thresholds.
class ThresholdSettings {
  ThresholdSettings({
    required this.sendIntervalOnSeconds,
    required this.sendIntervalOffSeconds,
    required this.autoDelaySeconds,
    required this.autoMaxDurationMinutes,
    required this.autoModeEnabled,
    required this.vMin,
    required this.vMax,
    required this.phasedownVoltage,
    required this.phasedownEnabled,
    required this.overVoltageEnabled,
    required this.underVoltageEnabled,
    required this.iMin,
    required this.iMax,
    required this.overloadEnabled,
    required this.dryRunEnabled,
    required this.reversePhaseEnabled,
    required this.motorHp,
    required this.supplyVoltage,
    required this.phaseType,
    required this.currentAutoCalculated,
  });

  final int sendIntervalOnSeconds;
  final int sendIntervalOffSeconds;
  final int autoDelaySeconds;
  final int autoMaxDurationMinutes;
  final bool autoModeEnabled;

  final double vMin;
  final double vMax;
  final double phasedownVoltage;
  final bool phasedownEnabled;
  final bool overVoltageEnabled;
  final bool underVoltageEnabled;

  final double iMin;
  final double iMax;
  final bool overloadEnabled;

  final bool dryRunEnabled;
  final bool reversePhaseEnabled;

  final double motorHp;
  final SupplyVoltage supplyVoltage;
  final PhaseType phaseType;

  /// Whether iMin/iMax currently reflect the HP-based formula
  /// (false once the operator manually overrides them).
  final bool currentAutoCalculated;

  /// Standard estimate: full-load amps ~= (HP * 746) / (V * PF * sqrt(3 or 1)).
  /// PF assumed 0.85, a typical motor power factor.
  static double estimateFullLoadAmps({
    required double hp,
    required SupplyVoltage voltage,
    required PhaseType phase,
  }) {
    const powerFactor = 0.85;
    final watts = hp * 746;
    final phaseFactor = phase == PhaseType.three ? 1.732 : 1.0;
    return watts / (voltage.volts * phaseFactor * powerFactor);
  }

  ({double iMin, double iMax}) recalculatedCurrentRange() {
    final flAmps = estimateFullLoadAmps(
      hp: motorHp,
      voltage: supplyVoltage,
      phase: phaseType,
    );
    return (iMin: flAmps * 0.4, iMax: flAmps * 1.15);
  }

  ThresholdSettings copyWith({
    int? sendIntervalOnSeconds,
    int? sendIntervalOffSeconds,
    int? autoDelaySeconds,
    int? autoMaxDurationMinutes,
    bool? autoModeEnabled,
    double? vMin,
    double? vMax,
    double? phasedownVoltage,
    bool? phasedownEnabled,
    bool? overVoltageEnabled,
    bool? underVoltageEnabled,
    double? iMin,
    double? iMax,
    bool? overloadEnabled,
    bool? dryRunEnabled,
    bool? reversePhaseEnabled,
    double? motorHp,
    SupplyVoltage? supplyVoltage,
    PhaseType? phaseType,
    bool? currentAutoCalculated,
  }) {
    return ThresholdSettings(
      sendIntervalOnSeconds: sendIntervalOnSeconds ?? this.sendIntervalOnSeconds,
      sendIntervalOffSeconds: sendIntervalOffSeconds ?? this.sendIntervalOffSeconds,
      autoDelaySeconds: autoDelaySeconds ?? this.autoDelaySeconds,
      autoMaxDurationMinutes: autoMaxDurationMinutes ?? this.autoMaxDurationMinutes,
      autoModeEnabled: autoModeEnabled ?? this.autoModeEnabled,
      vMin: vMin ?? this.vMin,
      vMax: vMax ?? this.vMax,
      phasedownVoltage: phasedownVoltage ?? this.phasedownVoltage,
      phasedownEnabled: phasedownEnabled ?? this.phasedownEnabled,
      overVoltageEnabled: overVoltageEnabled ?? this.overVoltageEnabled,
      underVoltageEnabled: underVoltageEnabled ?? this.underVoltageEnabled,
      iMin: iMin ?? this.iMin,
      iMax: iMax ?? this.iMax,
      overloadEnabled: overloadEnabled ?? this.overloadEnabled,
      dryRunEnabled: dryRunEnabled ?? this.dryRunEnabled,
      reversePhaseEnabled: reversePhaseEnabled ?? this.reversePhaseEnabled,
      motorHp: motorHp ?? this.motorHp,
      supplyVoltage: supplyVoltage ?? this.supplyVoltage,
      phaseType: phaseType ?? this.phaseType,
      currentAutoCalculated: currentAutoCalculated ?? this.currentAutoCalculated,
    );
  }
}
