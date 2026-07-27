import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/errors/error_presentation.dart';
import '../../../../core/formatting/money.dart';
import '../../../../core/state/ledger_revision_provider.dart';
import '../../../../core/widgets/amount_field.dart';
import '../../../../core/widgets/first_day_of_week_scope.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../account/presentation/view_models/account_providers.dart';
import '../../../wallets/data/providers.dart';
import '../../data/providers.dart';
import '../../domain/models/ledger_transaction.dart';

/// Edits a wallet's OPENING_BALANCE entry — amount and date only (plan.md
/// section 13.3 extension). Kept as its own small sheet rather than
/// routing into the full transaction form: wallet/title/category/direction
/// are structural to what makes it an opening balance and stay fixed (see
/// [LedgerTransaction.isOpeningBalanceEditable]'s doc comment).
class OpeningBalanceEditSheet extends ConsumerStatefulWidget {
  const OpeningBalanceEditSheet({super.key, required this.transaction});

  final LedgerTransaction transaction;

  static Future<bool> show(
    BuildContext context, {
    required LedgerTransaction transaction,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => OpeningBalanceEditSheet(transaction: transaction),
    );
    return result ?? false;
  }

  @override
  ConsumerState<OpeningBalanceEditSheet> createState() =>
      _OpeningBalanceEditSheetState();
}

class _OpeningBalanceEditSheetState
    extends ConsumerState<OpeningBalanceEditSheet> {
  late final _amountController = TextEditingController(
    text: (widget.transaction.amount.minorUnits / 100).toStringAsFixed(2),
  );
  late DateTime _occurredAt = widget.transaction.occurredAt.toLocal();
  String? _amountError;
  AppError? _error;
  bool _isSaving = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
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

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_occurredAt),
    );
    if (time == null || !mounted) return;

    setState(() {
      _occurredAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _submit() async {
    final amountMinor = Money.parseMinorUnits(_amountController.text);
    if (amountMinor == null || amountMinor <= 0) {
      setState(
        () =>
            _amountError = AppLocalizations.of(context).errorCodeInvalidAmount,
      );
      return;
    }
    setState(() {
      _amountError = null;
      _error = null;
      _isSaving = true;
    });

    try {
      await ref
          .read(transactionRepositoryProvider)
          .updateOpeningBalance(
            widget.transaction.id,
            amountMinor: amountMinor,
            occurredAt: _occurredAt,
            expectedVersion: widget.transaction.version,
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
    final dateFormat = DateFormat('d MMMM y, HH:mm', 'it_IT');
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
            l10n.editOpeningBalanceSheetTitle,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.editOpeningBalanceHint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          AmountField(
            controller: _amountController,
            errorText: _amountError,
            currencySymbol: widget.transaction.amount.currency == 'EUR'
                ? '€'
                : widget.transaction.amount.currency,
          ),
          const SizedBox(height: AppSpacing.sm),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.dateAndTimeLabel),
            subtitle: Text(dateFormat.format(_occurredAt)),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: _pickDateTime,
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
                : Text(l10n.saveOpeningBalanceAction),
          ),
        ],
      ),
    );
  }
}
