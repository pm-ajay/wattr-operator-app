import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Water Volume Calculator: given the pump's known discharge rate, works
/// out how long a schedule needs to run to deliver a target volume.
/// Returns the computed duration in minutes if the operator taps
/// "Use this duration", or null if they just dismiss the sheet.
Future<int?> showWaterCalculatorSheet(
  BuildContext context, {
  required String pumpLabel,
  required double dischargeLps,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _WaterCalculatorContent(pumpLabel: pumpLabel, dischargeLps: dischargeLps),
    ),
  );
}

class _WaterCalculatorContent extends StatefulWidget {
  const _WaterCalculatorContent({required this.pumpLabel, required this.dischargeLps});

  final String pumpLabel;
  final double dischargeLps;

  @override
  State<_WaterCalculatorContent> createState() => _WaterCalculatorContentState();
}

class _WaterCalculatorContentState extends State<_WaterCalculatorContent> {
  final _litersController = TextEditingController();

  @override
  void dispose() {
    _litersController.dispose();
    super.dispose();
  }

  double get _litersPerMinute => widget.dischargeLps * 60;

  /// Rounded up so the schedule always delivers at least the requested
  /// volume, never slightly short of it.
  int? get _durationMinutes {
    final liters = double.tryParse(_litersController.text);
    if (liters == null || liters <= 0) return null;
    return (liters / _litersPerMinute).ceil();
  }

  String _formatDuration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '$m min';
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final duration = _durationMinutes;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Water Volume Calculator', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'Work out how long ${widget.pumpLabel} needs to run to deliver a target amount of water.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.water_drop_outlined, size: 18, color: theme.colorScheme.outline),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Discharge rate: ${widget.dischargeLps.toStringAsFixed(1)} L/s '
                      '(${_litersPerMinute.toStringAsFixed(0)} L/min)',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _litersController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Water Needed',
                suffixText: 'liters',
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Time needed',
                    style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onPrimaryContainer),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    duration != null ? _formatDuration(duration) : '—',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Duration = Water Needed ÷ (Discharge Rate × 60), rounded up so you never fall short.',
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onPrimaryContainer),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: duration != null ? () => Navigator.of(context).pop(duration) : null,
                child: const Text('Use this duration for a new schedule'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
