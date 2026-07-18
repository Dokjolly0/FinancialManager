import 'package:flutter/material.dart';

/// Credit/debit toggle (plan.md section 7.6). Kept in terms of a plain
/// [isCredit] bool rather than a feature-specific enum so this stays a
/// core, domain-agnostic widget.
class DirectionSegmentedControl extends StatelessWidget {
  const DirectionSegmentedControl({
    super.key,
    required this.isCredit,
    required this.onChanged,
    this.debitLabel = 'Uscita',
    this.creditLabel = 'Entrata',
  });

  final bool isCredit;
  final ValueChanged<bool> onChanged;
  final String debitLabel;
  final String creditLabel;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<bool>(
      segments: [
        ButtonSegment(
          value: false,
          label: Text(debitLabel),
          icon: const Icon(Icons.remove),
        ),
        ButtonSegment(
          value: true,
          label: Text(creditLabel),
          icon: const Icon(Icons.add),
        ),
      ],
      selected: {isCredit},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}
