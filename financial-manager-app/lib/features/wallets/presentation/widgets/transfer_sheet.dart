import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/errors/error_presentation.dart';
import '../../../../core/formatting/color_hex.dart';
import '../../../../core/formatting/money.dart';
import '../../../../core/state/ledger_revision_provider.dart';
import '../../../../core/widgets/amount_field.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../transactions/data/providers.dart';
import '../../data/providers.dart';
import '../../domain/models/wallet.dart';
import 'wallet_icon_data.dart';
import 'wallet_picker_sheet.dart';

/// Atomic wallet-to-wallet transfer (plan.md: "un'aggiunta o ricarica di
/// credito da un conto ad un altro"): two wallet pickers + an amount, no
/// direction/category/title fields since a transfer isn't a standard
/// expense or income and never appears in report totals.
class TransferSheet extends ConsumerStatefulWidget {
  const TransferSheet({super.key});

  static Future<bool> show(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const TransferSheet(),
    );
    return result ?? false;
  }

  @override
  ConsumerState<TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends ConsumerState<TransferSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  Wallet? _source;
  Wallet? _destination;
  String? _amountError;
  String? _walletError;
  bool _isSaving = false;
  AppError? _error;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickSource() async {
    final selected = await WalletPickerSheet.show(context);
    if (selected == null || !mounted) return;
    setState(() {
      _source = selected;
      if (_destination?.id == selected.id) _destination = null;
      _walletError = null;
    });
  }

  Future<void> _pickDestination() async {
    final selected = await WalletPickerSheet.show(
      context,
      excludeWalletId: _source?.id,
    );
    if (selected == null || !mounted) return;
    setState(() {
      _destination = selected;
      _walletError = null;
    });
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final source = _source;
    final destination = _destination;
    final amountMinor = Money.parseMinorUnits(_amountController.text);

    setState(() {
      _amountError = (amountMinor == null || amountMinor <= 0)
          ? l10n.errorCodeInvalidAmount
          : null;
      _walletError = (source == null || destination == null)
          ? l10n.selectWalletPlaceholder
          : (source.id == destination.id ? l10n.transferSameWalletError : null);
    });
    if (_amountError != null || _walletError != null) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await ref
          .read(transactionRepositoryProvider)
          .createTransfer(
            sourceWalletId: source!.id,
            destinationWalletId: destination!.id,
            amountMinor: amountMinor!,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
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

  Widget _walletTile(BuildContext context, String label, Wallet? wallet, VoidCallback onTap) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: wallet == null
          ? const Icon(Icons.account_balance_wallet_outlined)
          : CircleAvatar(
              backgroundColor: colorFromHex(wallet.color),
              child: Icon(
                iconForWalletKey(wallet.icon),
                color: Colors.white,
                size: 20,
              ),
            ),
      title: Text(label),
      subtitle: Text(wallet?.name ?? l10n.selectWalletPlaceholder),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
            l10n.transferSheetTitle,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          _walletTile(
            context,
            l10n.transferSourceWalletLabel,
            _source,
            _pickSource,
          ),
          const Divider(height: 1),
          _walletTile(
            context,
            l10n.transferDestinationWalletLabel,
            _destination,
            _pickDestination,
          ),
          if (_walletError != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              _walletError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          AmountField(controller: _amountController, errorText: _amountError),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _noteController,
            decoration: InputDecoration(labelText: l10n.transferNoteLabel),
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
                : Text(l10n.submitTransferAction),
          ),
        ],
      ),
    );
  }
}
