import 'package:flutter/material.dart';

import '../models/pump_status.dart';

/// Generic three-tier severity colors, reused across two independent
/// contexts: pump run-state (running/caution/off) and reading safety
/// margins on threshold bars (normal/near-limit/out-of-range). Every usage
/// should pair color with an icon/text label (accessibility NFR).
class StatusColors {
  const StatusColors._();

  static const good = Color(0xFF2E7D32);
  static const goodBg = Color(0xFFE6F4EA);

  static const warn = Color(0xFFB8860B);
  static const warnBg = Color(0xFFFFF4DE);

  static const crit = Color(0xFFC62828);
  static const critBg = Color(0xFFFCE8E8);

  static Color colorFor(PumpSeverity severity) => switch (severity) {
        PumpSeverity.running => good,
        PumpSeverity.caution => warn,
        PumpSeverity.off => crit,
      };

  static Color bgFor(PumpSeverity severity) => switch (severity) {
        PumpSeverity.running => goodBg,
        PumpSeverity.caution => warnBg,
        PumpSeverity.off => critBg,
      };
}
