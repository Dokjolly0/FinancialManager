import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/errors/error_presentation.dart';
import '../../../../core/formatting/money.dart';
import '../../../../core/state/ledger_revision_provider.dart';
import '../../../../core/widgets/first_day_of_week_scope.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../account/presentation/view_models/account_providers.dart';
import '../../../transactions/data/providers.dart';
import '../../../transactions/domain/repositories/transaction_repository.dart';
import '../../data/providers.dart';

/// Adds a new batch of vouchers (a lot, expiry computed server-side from
/// the wallet's policy) or removes vouchers outside of a purchase (e.g.
/// lost, miscounted) — consumed FIFO like a spend. Mirrors
/// BalanceAdjustmentSheet's shape, but the unit of input is a voucher
/// count, not a free amount.
class VoucherCreditSheet extends ConsumerStatefulWidget {
  const VoucherCreditSheet({
    super.key,
    required this.walletId,
    required this.isAddition,
    required this.unitValueMinor,
    required this.currency,
  });

  final String walletId;
  final bool isAddition;
  final int unitValueMinor;
  final String currency;

  static Future<bool> show(
    BuildContext context, {
    required String walletId,
    required bool isAddition,
    required int unitValueMinor,
    required String currency,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => VoucherCreditSheet(
        walletId: walletId,
        isAddition: isAddition,
        unitValueMinor: unitValueMinor,
        currency: currency,
      ),
    );
    return result ?? false;
  }

  @override
  ConsumerState<VoucherCreditSheet> createState() =>
      _VoucherCreditSheetState();
}

class _VoucherCreditSheetState extends ConsumerState<VoucherCreditSheet> {
  final _quantityController = TextEditingController(text: '1');
  final _reasonController = TextEditingController();
  DateTime _occurredAt = DateTime.now();
  String? _quantityError;
  AppError? _error;
  bool _isSaving = false;

  @override
  void dispose() {
    _quantityController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  int get _quantity => int.tryParse(_quantityController.text.trim()) ?? 0;

  Future<void> _pickDate() async {
    final firstDayOfWeek =
        ref.read(accountProfileProvider).value?.firstDayOfWeek ?? 'monday';
    final date = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) =>
          firstDayOfWeekScope(context, child, firstDayOfWeek),
    );
    if (date == null || !mounted) return;
    setState(() => _occurredAt = date);
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (_quantity <= 0) {
      setState(() => _quantityError = l10n.errorCodeAmountNotPositive);
      return;
    }
    setState(() {
      _quantityError = null;
      _error = null;
      _isSaving = true;
    });

    try {
      await ref
          .read(transactionRepositoryProvider)
          .createVoucherCredit(
            CreateVoucherCreditParams(
              walletId: widget.walletId,
              quantity: widget.isAddition ? _quantity : -_quantity,
              reason: _reasonController.text.trim().isEmpty
                  ? null
                  : _reasonController.text.trim(),
              occurredAt: _occurredAt,
            ),
          );
      ref.invalidate(walletsListProvider);
      ref.read(ledgerRevisionProvider.notifier).state++;
      if (mounted) Navigator.of(context).pop(true);
    } on AppError catch (e) {
      setState(() {
        _isSaving = false;
        _error = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final previewValue = Money(
      minorUnits: _quantity * widget.unitValueMinor,
      currency: widget.currency,
    );
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
            widget.isAddition
                ? l10n.addVouchersSheetTitle
                : l10n.removeVouchersSheetTitle,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _quantityController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displayLarge,
            decoration: InputDecoration(
              labelText: l10n.voucherQuantityLabel,
              errorText: _quantityError,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            previewValue.format(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              widget.isAddition
                  ? l10n.voucherLoadedAtLabel
                  : l10n.dateAndTimeLabel,
            ),
            subtitle: Text(
              DateFormat('d MMMM y', 'it_IT').format(_occurredAt),
            ),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: _pickDate,
          ),
          TextField(
            controller: _reasonController,
            decoration: InputDecoration(labelText: l10n.reasonOptionalLabel),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              presentError(_error!, l10n).message,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: _isSaving ? null : _submit,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    widget.isAddition
                        ? l10n.addVouchersAction
                        : l10n.removeVouchersAction,
                  ),
          ),
        ],
      ),
    );
  }
}
