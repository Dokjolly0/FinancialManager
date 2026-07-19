import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/errors/error_presentation.dart';
import '../../../../core/formatting/money.dart';
import '../../../../core/state/ledger_revision_provider.dart';
import '../../../../core/widgets/amount_field.dart';
import '../../../transactions/data/providers.dart';
import '../view_models/account_providers.dart';

/// Rettifica saldo (plan.md sections 7.13 "Portafoglio", 8.4, 13.5): sets
/// the wallet to a target balance rather than asking for a delta — the
/// backend computes the difference server-side.
class BalanceAdjustmentSheet extends ConsumerStatefulWidget {
  const BalanceAdjustmentSheet({super.key, required this.currentBalance});

  final Money currentBalance;

  static Future<void> show(BuildContext context, Money currentBalance) {
    return showModalBottomSheet<void>(
      context: context,
      // See ConfirmationSheet's useRootNavigator comment — otherwise
      // AppShell's centerDocked FAB sits above this sheet's own buttons.
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => BalanceAdjustmentSheet(currentBalance: currentBalance),
    );
  }

  @override
  ConsumerState<BalanceAdjustmentSheet> createState() =>
      _BalanceAdjustmentSheetState();
}

class _BalanceAdjustmentSheetState
    extends ConsumerState<BalanceAdjustmentSheet> {
  late final _amountController = TextEditingController(
    text: (widget.currentBalance.minorUnits / 100).toStringAsFixed(2),
  );
  final _reasonController = TextEditingController();
  String? _amountError;
  bool _isSaving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final targetMinor = Money.parseMinorUnits(_amountController.text);
    if (targetMinor == null) {
      setState(() => _amountError = 'Importo non valido.');
      return;
    }
    setState(() {
      _amountError = null;
      _isSaving = true;
    });

    try {
      await ref
          .read(transactionRepositoryProvider)
          .createBalanceAdjustment(
            targetBalanceMinor: targetMinor,
            reason: _reasonController.text.trim().isEmpty
                ? null
                : _reasonController.text.trim(),
          );
      ref.invalidate(accountWalletProvider);
      ref.read(ledgerRevisionProvider.notifier).state++;
      if (mounted) Navigator.of(context).pop();
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(presentError(e).message)));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Rettifica saldo',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Saldo attuale: ${widget.currentBalance.format()}',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          AmountField(
            controller: _amountController,
            errorText: _amountError,
            currencySymbol: widget.currentBalance.currency == 'EUR'
                ? '€'
                : widget.currentBalance.currency,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _reasonController,
            decoration: const InputDecoration(
              labelText: 'Motivo (opzionale)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: _isSaving ? null : _submit,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Salva rettifica'),
          ),
        ],
      ),
    );
  }
}
