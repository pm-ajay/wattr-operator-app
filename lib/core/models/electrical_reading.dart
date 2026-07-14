enum Phase { r, y, b }

extension PhaseX on Phase {
  String get label => switch (this) {
        Phase.r => 'R',
        Phase.y => 'Y',
        Phase.b => 'B',
      };
}

/// A single phase's reading against its configured safe range.
class PhaseReading {
  const PhaseReading({required this.phase, required this.value, required this.min, required this.max});

  final Phase phase;
  final double value;
  final double min;
  final double max;

  bool get isBelowMin => value < min;
  bool get isAboveMax => value > max;
  bool get isOutOfRange => isBelowMin || isAboveMax;

  /// 0.0-1.0+ position within [min, max]; can exceed the range on either side.
  double get fraction {
    final span = max - min;
    if (span <= 0) return 0.5;
    return (value - min) / span;
  }

  bool get isNearLimit {
    if (isOutOfRange) return false;
    const nearBand = 0.1;
    return fraction <= nearBand || fraction >= 1 - nearBand;
  }
}
