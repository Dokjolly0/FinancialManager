import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/errors/error_presentation.dart';
import '../../../../core/formatting/color_hex.dart';
import '../../../../core/formatting/money.dart';
import '../../../../core/state/ledger_revision_provider.dart';
import '../../../../core/widgets/amount_field.dart';
import '../../../../core/widgets/first_day_of_week_scope.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../account/presentation/view_models/account_providers.dart';
import '../../../media/data/providers.dart';
import '../../../media/domain/models/media_asset.dart';
import '../../../media/presentation/widgets/image_picker_sheet.dart';
import '../../../transactions/data/providers.dart';
import '../../../transactions/domain/models/ledger_transaction.dart';
import '../../../transactions/domain/repositories/transaction_repository.dart';
import '../../data/providers.dart';
import '../../domain/models/wallet.dart';
import '../../domain/models/wallet_type.dart';
import 'wallet_icon_data.dart';
import 'wallet_picker_sheet.dart';

/// Records (or edits) a purchase paid partly or fully with meal vouchers:
/// a total real cost, how many vouchers to use (validated against
/// availability server-side, with a client-side minimum-needed suggestion),
/// and — only if the vouchers' value falls short of the real cost — which
/// other wallet covers the difference. Also lets the user attach an image,
/// same as the standard transaction form (plan.md section 7.7) — no
/// category/template though, since this is a focused flow.
class VoucherExpenseSheet extends ConsumerStatefulWidget {
  const VoucherExpenseSheet({
    super.key,
    this.editVoucherTransaction,
    this.editVoucherWallet,
    this.editOtherTransaction,
    this.editOtherWallet,
  });

  /// When editing, the voucher-wallet leg being edited and its wallet.
  final LedgerTransaction? editVoucherTransaction;
  final Wallet? editVoucherWallet;

  /// The existing difference leg/wallet, if the original expense had one.
  final LedgerTransaction? editOtherTransaction;
  final Wallet? editOtherWallet;

  bool get isEditing => editVoucherTransaction != null;

  static Future<bool> show(
    BuildContext context, {
    LedgerTransaction? editVoucherTransaction,
    Wallet? editVoucherWallet,
    LedgerTransaction? editOtherTransaction,
    Wallet? editOtherWallet,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => VoucherExpenseSheet(
        editVoucherTransaction: editVoucherTransaction,
        editVoucherWallet: editVoucherWallet,
        editOtherTransaction: editOtherTransaction,
        editOtherWallet: editOtherWallet,
      ),
    );
    return result ?? false;
  }

  @override
  ConsumerState<VoucherExpenseSheet> createState() =>
      _VoucherExpenseSheetState();
}

class _VoucherExpenseSheetState extends ConsumerState<VoucherExpenseSheet> {
  late final _totalController = TextEditingController(
    text: widget.isEditing
        ? (_initialTotalMinor / 100).toStringAsFixed(2)
        : null,
  );
  late final _quantityController = TextEditingController(
    text: widget.isEditing ? '$_initialQuantity' : '1',
  );
  late final _titleController = TextEditingController(
    text: widget.editVoucherTransaction?.title ?? '',
  );
  late final _descriptionController = TextEditingController(
    text: widget.editVoucherTransaction?.description ?? '',
  );
  Wallet? _voucherWallet;
  Wallet? _otherWallet;
  late String? _mediaId = widget.editVoucherTransaction?.mediaId;
  late DateTime _occurredAt =
      widget.editVoucherTransaction?.occurredAt.toLocal() ?? DateTime.now();
  String? _totalError;
  String? _quantityError;
  String? _titleError;
  String? _walletError;
  AppError? _error;
  bool _isSaving = false;
  bool _isLoadingWallets = true;

  int get _initialQuantity {
    final wallet = widget.editVoucherWallet;
    final tx = widget.editVoucherTransaction;
    if (wallet?.voucherUnitValueMinor == null || tx == null) return 1;
    return tx.amount.minorUnits ~/ wallet!.voucherUnitValueMinor!;
  }

  int get _initialTotalMinor {
    final tx = widget.editVoucherTransaction;
    final other = widget.editOtherTransaction;
    if (tx == null) return 0;
    return tx.amount.minorUnits + (other?.amount.minorUnits ?? 0);
  }

  @override
  void initState() {
    super.initState();
    _voucherWallet = widget.editVoucherWallet;
    _otherWallet = widget.editOtherWallet;
    if (widget.isEditing) {
      _isLoadingWallets = false;
    } else {
      _pickDefaultVoucherWallet();
    }
  }

  Future<void> _pickDefaultVoucherWallet() async {
    final wallets = await ref.read(walletsListProvider.future);
    final voucherWallets = wallets.where((w) => w.isMealVoucher).toList();
    if (!mounted) return;
    setState(() {
      if (voucherWallets.length == 1) _voucherWallet = voucherWallets.first;
      _isLoadingWallets = false;
    });
  }

  @override
  void dispose() {
    _totalController.dispose();
    _quantityController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  int get _quantity => int.tryParse(_quantityController.text.trim()) ?? 0;

  String? get _description => _descriptionController.text.trim().isEmpty
      ? null
      : _descriptionController.text.trim();

  int get _shortfallMinor {
    final wallet = _voucherWallet;
    final totalMinor = Money.parseMinorUnits(_totalController.text) ?? 0;
    if (wallet?.voucherUnitValueMinor == null) return 0;
    final voucherValue = _quantity * wallet!.voucherUnitValueMinor!;
    final diff = totalMinor - voucherValue;
    return diff > 0 ? diff : 0;
  }

  Future<void> _pickVoucherWallet() async {
    if (widget.isEditing) return;
    final selected = await WalletPickerSheet.show(
      context,
      typeFilter: const {WalletType.mealVoucher},
    );
    if (selected == null || !mounted) return;
    setState(() {
      _voucherWallet = selected;
      _walletError = null;
    });
  }

  Future<void> _pickOtherWallet() async {
    final selected = await WalletPickerSheet.show(
      context,
      excludeWalletId: _voucherWallet?.id,
      typeFilter: WalletType.values
          .where((t) => t != WalletType.mealVoucher)
          .toSet(),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _otherWallet = selected;
      _walletError = null;
    });
  }

  Future<void> _pickImage() async {
    final selected = await ImagePickerSheet.show(
      context,
      kind: MediaKind.transaction,
    );
    if (selected == null || !mounted) return;
    setState(() => _mediaId = selected.id);
  }

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
    final l10n = AppLocalizations.of(context);
    final totalMinor = Money.parseMinorUnits(_totalController.text);
    final voucherWallet = _voucherWallet;
    final shortfall = _shortfallMinor;

    setState(() {
      _totalError = (totalMinor == null || totalMinor <= 0)
          ? l10n.errorCodeAmountNotPositive
          : null;
      _quantityError = _quantity <= 0 ? l10n.errorCodeAmountNotPositive : null;
      _titleError = _titleController.text.trim().isEmpty
          ? l10n.errorCodeRequiredField
          : null;
      _walletError = voucherWallet == null
          ? l10n.selectWalletPlaceholder
          : (shortfall > 0 && _otherWallet == null)
          ? l10n.voucherOtherWalletRequiredError
          : null;
    });
    if (_totalError != null ||
        _quantityError != null ||
        _titleError != null ||
        _walletError != null) {
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final repo = ref.read(transactionRepositoryProvider);
      if (widget.isEditing) {
        await repo.updateVoucherExpense(
          widget.editVoucherTransaction!.id,
          UpdateVoucherExpenseParams(
            voucherQuantity: _quantity,
            totalExpenseMinor: totalMinor!,
            otherWalletId: shortfall > 0 ? _otherWallet!.id : null,
            title: _titleController.text.trim(),
            description: _description,
            mediaId: _mediaId,
            occurredAt: _occurredAt,
            expectedVersion: widget.editVoucherTransaction!.version,
          ),
        );
      } else {
        await repo.createVoucherExpense(
          CreateVoucherExpenseParams(
            voucherWalletId: voucherWallet!.id,
            voucherQuantity: _quantity,
            totalExpenseMinor: totalMinor!,
            otherWalletId: shortfall > 0 ? _otherWallet!.id : null,
            title: _titleController.text.trim(),
            description: _description,
            mediaId: _mediaId,
            occurredAt: _occurredAt,
          ),
        );
      }
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

  Widget _walletTile(
    BuildContext context,
    String label,
    Wallet? wallet,
    VoidCallback? onTap,
  ) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: onTap != null,
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
      trailing: onTap == null ? null : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final voucherWallet = _voucherWallet;
    final shortfall = _shortfallMinor;
    final suggestedQuantity =
        voucherWallet?.voucherUnitValueMinor != null &&
            voucherWallet!.voucherUnitValueMinor! > 0
        ? ((Money.parseMinorUnits(_totalController.text) ?? 0) /
                  voucherWallet.voucherUnitValueMinor!)
              .ceil()
        : null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: _isLoadingWallets
          ? const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.isEditing
                      ? l10n.editVoucherExpenseSheetTitle
                      : l10n.voucherExpenseSheetTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                _walletTile(
                  context,
                  l10n.voucherWalletLabel,
                  voucherWallet,
                  widget.isEditing ? null : _pickVoucherWallet,
                ),
                if (_walletError != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _walletError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: l10n.titleFieldLabel,
                    errorText: _titleError,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: l10n.descriptionOptionalLabel,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.voucherTotalExpenseLabel,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                AmountField(
                  controller: _totalController,
                  errorText: _totalError,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.voucherQuantityLabel,
                    errorText: _quantityError,
                    helperText: suggestedQuantity != null
                        ? l10n.voucherSuggestedQuantityHelper(suggestedQuantity)
                        : null,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                if (shortfall > 0) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    l10n.voucherShortfallLabel(
                      Money(minorUnits: shortfall, currency: 'EUR').format(),
                    ),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  _walletTile(
                    context,
                    l10n.voucherOtherWalletLabel,
                    _otherWallet,
                    _pickOtherWallet,
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: _mediaId == null
                      ? const Icon(Icons.image_outlined)
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.inputRadius,
                          ),
                          child: Image(
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            image: NetworkImage(
                              ref
                                  .read(mediaRepositoryProvider)
                                  .contentUrl(_mediaId!),
                              headers: ref
                                  .read(mediaRepositoryProvider)
                                  .authHeaders(),
                            ),
                          ),
                        ),
                  title: Text(
                    _mediaId == null
                        ? l10n.noImageSelectedLabel
                        : l10n.imageSelectedLabel,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _pickImage,
                ),
                const SizedBox(height: AppSpacing.sm),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.dateAndTimeLabel),
                  subtitle: Text(
                    DateFormat('d MMMM y, HH:mm', 'it_IT').format(_occurredAt),
                  ),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: _pickDate,
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    presentError(_error!, l10n).message,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
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
                          widget.isEditing
                              ? l10n.saveVoucherExpenseAction
                              : l10n.submitVoucherExpenseAction,
                        ),
                ),
              ],
            ),
    );
  }
}
