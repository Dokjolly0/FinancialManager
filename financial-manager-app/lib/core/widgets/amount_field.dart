import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Prominent numeric amount input (plan.md section 7.6): numeric keyboard,
/// decimal separator only, no manual minus sign — direction is chosen via
/// a separate control, never typed.
class AmountField extends StatelessWidget {
  const AmountField({
    super.key,
    required this.controller,
    this.errorText,
    this.currencySymbol = '€',
  });

  final TextEditingController controller;
  final String? errorText;
  final String currencySymbol;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))],
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.displayLarge,
      decoration: InputDecoration(
        prefixText: '$currencySymbol ',
        border: InputBorder.none,
        errorText: errorText,
        errorBorder: InputBorder.none,
      ),
    );
  }
}
