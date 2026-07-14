import 'package:flutter/material.dart';

import '../models/pump_status.dart';

/// Compact icon set for the dashboard status ring — one glyph per cause,
/// deliberately coarser than the detail screen's per-fault icons since this
/// has to stay readable at a glance across a long list.
IconData iconForStatus(PumpStatus status) => switch (status) {
      PumpStatus.on => Icons.water_drop,
      PumpStatus.offRemote => Icons.settings_remote,
      PumpStatus.offBypass => Icons.toggle_off,
      PumpStatus.offPowerDown => Icons.power_off,
      PumpStatus.faultOvervoltage ||
      PumpStatus.faultUndervoltage ||
      PumpStatus.faultOverload ||
      PumpStatus.faultDryRun ||
      PumpStatus.faultReversePhase =>
        Icons.warning_amber_rounded,
    };
