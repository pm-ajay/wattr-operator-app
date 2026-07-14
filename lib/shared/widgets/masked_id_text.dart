import 'package:flutter/material.dart';

/// Shows only the last 5 digits of a device identifier, per the
/// data-privacy requirement — full IMEI must never appear in the UI.
class MaskedIdText extends StatelessWidget {
  const MaskedIdText({super.key, required this.fullId, this.style});

  final String fullId;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final last5 = fullId.length > 5 ? fullId.substring(fullId.length - 5) : fullId;
    final base = style ?? Theme.of(context).textTheme.bodySmall;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.perm_device_information, size: 13, color: base?.color?.withValues(alpha: 0.6)),
        const SizedBox(width: 4),
        Text('•••••$last5', style: base),
      ],
    );
  }
}
