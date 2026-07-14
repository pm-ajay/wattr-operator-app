import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A settings input paired with a plain-language label and short
/// description, so operators never see a raw parameter with no context.
class LabeledNumberField extends StatelessWidget {
  const LabeledNumberField({
    super.key,
    required this.label,
    required this.description,
    required this.controller,
    this.suffixText,
    this.errorText,
    this.enabled = true,
    this.allowDecimal = true,
  });

  final String label;
  final String description;
  final TextEditingController controller;
  final String? suffixText;
  final String? errorText;
  final bool enabled;
  final bool allowDecimal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(width: 4),
              Tooltip(
                message: description,
                triggerMode: TooltipTriggerMode.tap,
                child: Icon(Icons.info_outline, size: 15, color: theme.colorScheme.outline),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(description, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            enabled: enabled,
            keyboardType: TextInputType.numberWithOptions(decimal: allowDecimal),
            inputFormatters: [
              allowDecimal
                  ? FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                  : FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: InputDecoration(
              isDense: true,
              suffixText: suffixText,
              errorText: errorText,
            ),
          ),
        ],
      ),
    );
  }
}

class LabeledSwitch extends StatelessWidget {
  const LabeledSwitch({
    super.key,
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                Text(description, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
