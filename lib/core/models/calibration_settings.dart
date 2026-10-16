import 'electrical_reading.dart';

/// The current-transformer (CT) reference used to derive [CalibrationSettings.currentMultiplier]
/// from the technician's directly-measured output current, per device spec.
const ctReferenceAmps = 5.0;

/// Per-pump sensor calibration — set points and the current-transformer
/// scaling factor, configured by a technician during/after installation.
class CalibrationSettings {
  const CalibrationSettings({
    required this.outputCurrentAmps,
    required this.currentMultiplier,
    required this.voltageSetPoints,
    required this.currentSetPoints,
  });

  /// The output current (A) the technician measured directly on the CT —
  /// entering this (rather than a multiplier) is the whole point of this
  /// calibration step, since [currentMultiplier] is derived from it.
  final double outputCurrentAmps;

  /// currentMultiplier = outputCurrentAmps / [ctReferenceAmps]. Always kept
  /// in sync with outputCurrentAmps — never edited directly.
  final double currentMultiplier;

  final Map<Phase, double> voltageSetPoints;
  final Map<Phase, double> currentSetPoints;

  static double multiplierFor(double outputCurrentAmps) => outputCurrentAmps / ctReferenceAmps;

  CalibrationSettings copyWith({
    double? outputCurrentAmps,
    Map<Phase, double>? voltageSetPoints,
    Map<Phase, double>? currentSetPoints,
  }) {
    final newOutput = outputCurrentAmps ?? this.outputCurrentAmps;
    return CalibrationSettings(
      outputCurrentAmps: newOutput,
      currentMultiplier: multiplierFor(newOutput),
      voltageSetPoints: voltageSetPoints ?? this.voltageSetPoints,
      currentSetPoints: currentSetPoints ?? this.currentSetPoints,
    );
  }
}
