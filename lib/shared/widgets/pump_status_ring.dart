import 'package:flutter/material.dart';

import '../../core/models/pump_mode.dart';
import '../../core/models/pump_status.dart';
import '../../core/theme/status_colors.dart';
import '../../core/theme/status_icons.dart';

/// The single glanceable shape for a pump's status: color says severity
/// (green=running, yellow=fault, red=off for any reason), the icon says
/// why, and — only for a schedule-driven run — a progress arc fills in.
class PumpStatusRing extends StatefulWidget {
  const PumpStatusRing({
    super.key,
    required this.status,
    required this.mode,
    this.isStale = false,
    this.scheduleProgress,
    this.size = 64,
  });

  final PumpStatus status;
  final PumpMode mode;
  final bool isStale;

  /// 0.0-1.0 completion of an active scheduled run. Must stay null for any
  /// pump not currently on a schedule-driven run — the arc is never shown
  /// for Auto Mode or manual running, by design.
  final double? scheduleProgress;
  final double size;

  @override
  State<PumpStatusRing> createState() => _PumpStatusRingState();
}

class _PumpStatusRingState extends State<PumpStatusRing> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final severity = widget.status.severity;
    final color = StatusColors.colorFor(severity);
    final discSize = widget.size * 0.74;
    final isRunning = severity == PumpSeverity.running;
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    Widget disc = Container(
      width: discSize,
      height: discSize,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      alignment: Alignment.center,
      child: Icon(iconForStatus(widget.status), color: Colors.white, size: discSize * 0.5),
    );

    if (widget.isStale) {
      disc = Opacity(
        opacity: 0.55,
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0, 0, 0, 1, 0,
          ]),
          child: disc,
        ),
      );
    }

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.scheduleProgress != null)
            SizedBox(
              width: widget.size,
              height: widget.size,
              child: CircularProgressIndicator(
                value: widget.scheduleProgress,
                strokeWidth: 3.5,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: const AlwaysStoppedAnimation(StatusColors.good),
              ),
            ),
          if (isRunning && !widget.isStale && !reduceMotion)
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) {
                final t = _pulse.value;
                return Container(
                  width: discSize + t * 10,
                  height: discSize + t * 10,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: StatusColors.goodBg.withValues(alpha: 0.7 - t * 0.5)),
                );
              },
            ),
          disc,
          if (widget.mode == PumpMode.auto)
            Positioned(
              right: 0,
              bottom: 0,
              child: _Badge(
                color: theme.colorScheme.primary,
                child: const Text('A', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ),
          if (widget.isStale)
            Positioned(
              right: 0,
              top: 0,
              child: _Badge(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Icon(Icons.wifi_off, size: 11, color: theme.colorScheme.outline),
              ),
            ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}
