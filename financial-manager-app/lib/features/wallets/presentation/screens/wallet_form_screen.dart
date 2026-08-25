import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/errors/error_code_localizations.dart';
import '../../../../core/errors/error_presentation.dart';
import '../../../../core/formatting/color_hex.dart';
import '../../../../core/formatting/money.dart';
import '../../../../core/widgets/amount_field.dart';
import '../../../../core/widgets/confirmation_sheet.dart';
import '../../../../core/widgets/first_day_of_week_scope.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../account/presentation/view_models/account_providers.dart';
import '../../../transactions/data/providers.dart';
import '../../../transactions/domain/models/ledger_transaction.dart';
import '../../../transactions/presentation/widgets/opening_balance_edit_sheet.dart';
import '../../data/providers.dart';
import '../../domain/models/wallet.dart';
import '../../domain/models/wallet_type.dart';
import '../../domain/repositories/wallet_repository.dart';
import '../widgets/balance_adjustment_sheet.dart';
import '../widgets/wallet_icon_color_picker.dart';
import 'voucher_lots_screen.dart';
import 'wallet_denominations_screen.dart';

/// Create / edit a wallet (plan.md multi-wallet extension). Both modes
/// share this form, keyed by [editWalletId] like the transaction form —
/// null means "new wallet".
class WalletFormScreen extends ConsumerStatefulWidget {
  const WalletFormScreen({super.key, this.editWalletId});

  final String? editWalletId;

  @override
  ConsumerState<WalletFormScreen> createState() => _WalletFormScreenState();
}

class _WalletFormScreenState extends ConsumerState<WalletFormScreen> {
  final _nameController = TextEditingController();
  final _openingBalanceController = TextEditingController(text: '0');
  final _voucherUnitValueController = TextEditingController();
  final _initialVoucherQuantityController = TextEditingController(text: '0');
  WalletType _type = WalletType.other;
  String _icon = defaultWalletIcon;
  Color _color = colorFromHex(defaultWalletColor);
  int _voucherExpiryCutoffMonth = defaultVoucherExpiryCutoffMonth;
  int _voucherExpiryMonth = defaultVoucherExpiryMonth;
  int _voucherExpiryDay = defaultVoucherExpiryDay;
  DateTime _voucherLoadedAt = DateTime.now();
  int? _expectedVersion;
  Wallet? _existing;
  LedgerTransaction? _openingBalanceTransaction;
  bool _isLoadingExisting = false;
  bool _isSaving = false;
  bool _isArchiving = false;
  Map<String, String> _fieldErrors = {};
  AppError? _error;

  bool get _isEditMode => widget.editWalletId != null;

  @override
  void initState() {
    super.initState();
    if (widget.editWalletId != null) {
      _isLoadingExisting = true;
      _loadExisting(widget.editWalletId!);
    }
  }

  Future<void> _loadExisting(String id) async {
    try {
      final wallet = await ref.read(walletRepositoryProvider).getWallet(id);
      final openingBalanceTransaction = await ref
          .read(transactionRepositoryProvider)
          .getOpeningBalanceTransaction(id);
      if (!mounted) return;
      setState(() {
        _existing = wallet;
        _openingBalanceTransaction = openingBalanceTransaction;
        _nameController.text = wallet.name;
        _type = wallet.type;
        _icon = wallet.icon;
        _color = colorFromHex(wallet.color);
        _expectedVersion = wallet.version;
        if (wallet.voucherUnitValueMinor != null) {
          _voucherUnitValueController.text =
              (wallet.voucherUnitValueMinor! / 100).toStringAsFixed(2);
        }
        _voucherExpiryCutoffMonth =
            wallet.voucherExpiryCutoffMonth ?? defaultVoucherExpiryCutoffMonth;
        _voucherExpiryMonth =
            wallet.voucherExpiryMonth ?? defaultVoucherExpiryMonth;
        _voucherExpiryDay = wallet.voucherExpiryDay ?? defaultVoucherExpiryDay;
        _isLoadingExisting = false;
      });
    } on AppError catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingExisting = false;
        _error = e;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _openingBalanceController.dispose();
    _voucherUnitValueController.dispose();
    _initialVoucherQuantityController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _fieldErrors = {'name': 'REQUIRED_FIELD'});
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
      _fieldErrors = {};
    });

    try {
      if (_isEditMode) {
        await ref
            .read(walletRepositoryProvider)
            .updateWallet(
              widget.editWalletId!,
              UpdateWalletParams(
                name: name,
                type: _type,
                icon: _icon,
                color: colorToHex(_color),
                expectedVersion: _expectedVersion!,
                voucherExpiryCutoffMonth: _type == WalletType.mealVoucher
                    ? _voucherExpiryCutoffMonth
                    : null,
                voucherExpiryMonth: _type == WalletType.mealVoucher
                    ? _voucherExpiryMonth
                    : null,
                voucherExpiryDay: _type == WalletType.mealVoucher
                    ? _voucherExpiryDay
                    : null,
              ),
            );
      } else if (_type == WalletType.mealVoucher) {
        final voucherUnitValueMinor = Money.parseMinorUnits(
          _voucherUnitValueController.text,
        );
        final initialVoucherQuantity =
            int.tryParse(_initialVoucherQuantityController.text.trim()) ?? 0;
        await ref
            .read(walletRepositoryProvider)
            .createWallet(
              CreateWalletParams(
                name: name,
                type: _type,
                icon: _icon,
                color: colorToHex(_color),
                voucherUnitValueMinor: voucherUnitValueMinor,
                voucherExpiryCutoffMonth: _voucherExpiryCutoffMonth,
                voucherExpiryMonth: _voucherExpiryMonth,
                voucherExpiryDay: _voucherExpiryDay,
                initialVoucherQuantity: initialVoucherQuantity,
                voucherLoadedAt: _voucherLoadedAt,
              ),
            );
      } else {
        final openingBalanceMinor =
            Money.parseMinorUnits(_openingBalanceController.text) ?? 0;
        await ref
            .read(walletRepositoryProvider)
            .createWallet(
              CreateWalletParams(
                name: name,
                type: _type,
                icon: _icon,
                color: colorToHex(_color),
                openingBalanceMinor: openingBalanceMinor,
              ),
            );
      }
      ref.invalidate(walletsListProvider);
      if (mounted) context.pop(true);
    } on AppError catch (e) {
      setState(() {
        _isSaving = false;
        _error = e;
        _fieldErrors = e is DomainError ? e.fieldErrors : const {};
      });
    }
  }

  Future<void> _adjustBalance() async {
    final existing = _existing;
    if (existing == null) return;
    final changed = await BalanceAdjustmentSheet.show(
      context,
      walletId: existing.id,
      currentBalance: existing.balance,
    );
    if (changed && mounted) {
      await _loadExisting(existing.id);
    }
  }

  Future<void> _editOpeningBalance() async {
    final transaction = _openingBalanceTransaction;
    if (transaction == null) return;
    final changed = await OpeningBalanceEditSheet.show(
      context,
      transaction: transaction,
    );
    if (changed && mounted) {
      await _loadExisting(widget.editWalletId!);
    }
  }

  Future<void> _pickVoucherLoadedAt() async {
    final firstDayOfWeek =
        ref.read(accountProfileProvider).value?.firstDayOfWeek ?? 'monday';
    final date = await showDatePicker(
      context: context,
      initialDate: _voucherLoadedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) =>
          firstDayOfWeekScope(context, child, firstDayOfWeek),
    );
    if (date == null || !mounted) return;
    setState(() => _voucherLoadedAt = date);
  }

  Future<void> _archive() async {
    final l10n = AppLocalizations.of(context);
    final existing = _existing;
    if (existing == null) return;

    final confirmed = await ConfirmationSheet.show(
      context,
      title: l10n.archiveWalletConfirmTitle,
      message: existing.balance.isZero
          ? l10n.archiveWalletConfirmMessage
          : l10n.archiveWalletConfirmMessageWithBalance(
              existing.balance.format(),
            ),
      confirmLabel: l10n.archiveWalletAction,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isArchiving = true);
    try {
      await ref
          .read(walletRepositoryProvider)
          .archiveWallet(existing.id, expectedVersion: existing.version);
      ref.invalidate(walletsListProvider);
      if (mounted) context.pop(true);
    } on AppError catch (e) {
      if (!mounted) return;
      setState(() {
        _isArchiving = false;
        _error = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String? fieldError(String key) {
      final code = _fieldErrors[key];
      return code == null ? null : localizeErrorCode(l10n, code);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditMode ? l10n.editWalletScreenTitle : l10n.newWalletScreenTitle,
        ),
        actions: [
          if (_isEditMode)
            IconButton(
              icon: _isArchiving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.archive_outlined),
              tooltip: l10n.archiveWalletAction,
              onPressed: _isArchiving ? null : _archive,
            ),
        ],
      ),
      body: _isLoadingExisting
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: l10n.walletNameLabel,
                      errorText: fieldError('name'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    l10n.walletTypeLabel,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  SegmentedButton<WalletType>(
                    segments: [
                      ButtonSegment(
                        value: WalletType.cash,
                        label: Text(l10n.walletTypeCash),
                        // The backend forbids changing an existing wallet's
                        // type into or out of MEAL_VOUCHER (it would strand
                        // voucher_unit_value_minor against a mismatched
                        // type), so once a wallet is one kind or the other
                        // the picker only offers segments on the same side
                        // of that boundary.
                        enabled:
                            !_isEditMode ||
                            _existing?.type != WalletType.mealVoucher,
                      ),
                      ButtonSegment(
                        value: WalletType.bank,
                        label: Text(l10n.walletTypeBank),
                        enabled:
                            !_isEditMode ||
                            _existing?.type != WalletType.mealVoucher,
                      ),
                      ButtonSegment(
                        value: WalletType.other,
                        label: Text(l10n.walletTypeOther),
                        enabled:
                            !_isEditMode ||
                            _existing?.type != WalletType.mealVoucher,
                      ),
                      ButtonSegment(
                        value: WalletType.mealVoucher,
                        label: Text(l10n.walletTypeMealVoucher),
                        enabled:
                            !_isEditMode ||
                            _existing?.type == WalletType.mealVoucher,
                      ),
                    ],
                    selected: {_type},
                    onSelectionChanged: (selection) =>
                        setState(() => _type = selection.first),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  WalletIconColorPicker(
                    selectedIcon: _icon,
                    selectedColor: _color,
                    onIconSelected: (icon) => setState(() => _icon = icon),
                    onColorSelected: (color) => setState(() => _color = color),
                  ),
                  if (!_isEditMode && _type != WalletType.mealVoucher) ...[
                    const SizedBox(height: AppSpacing.lg),
                    AmountField(
                      controller: _openingBalanceController,
                      errorText: fieldError('opening_balance_minor'),
                    ),
                  ],
                  if (_type == WalletType.mealVoucher) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      l10n.voucherUnitValueLabel,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    if (_isEditMode)
                      Text(
                        _existing?.voucherUnitValueMinor != null
                            ? Money(
                                minorUnits: _existing!.voucherUnitValueMinor!,
                                currency: 'EUR',
                              ).format()
                            : '—',
                        style: Theme.of(context).textTheme.titleMedium,
                      )
                    else
                      AmountField(
                        controller: _voucherUnitValueController,
                        errorText: fieldError('voucher_unit_value_minor'),
                      ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      l10n.voucherExpiryPolicyLabel,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: _voucherExpiryCutoffMonth,
                            decoration: InputDecoration(
                              labelText: l10n.voucherExpiryCutoffMonthLabel,
                            ),
                            items: [
                              for (var m = 1; m <= 12; m++)
                                DropdownMenuItem(
                                  value: m,
                                  child: Text(_monthName(m)),
                                ),
                            ],
                            onChanged: (value) => setState(
                              () => _voucherExpiryCutoffMonth = value!,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<int>(
                            initialValue: _voucherExpiryMonth,
                            decoration: InputDecoration(
                              labelText: l10n.voucherExpiryMonthLabel,
                            ),
                            items: [
                              for (var m = 1; m <= 12; m++)
                                DropdownMenuItem(
                                  value: m,
                                  child: Text(_monthName(m)),
                                ),
                            ],
                            onChanged: (value) =>
                                setState(() => _voucherExpiryMonth = value!),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: _voucherExpiryDay,
                            decoration: InputDecoration(
                              labelText: l10n.voucherExpiryDayLabel,
                            ),
                            items: [
                              for (var d = 1; d <= 31; d++)
                                DropdownMenuItem(value: d, child: Text('$d')),
                            ],
                            onChanged: (value) =>
                                setState(() => _voucherExpiryDay = value!),
                          ),
                        ),
                      ],
                    ),
                    if (!_isEditMode) ...[
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: _initialVoucherQuantityController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: l10n.voucherInitialQuantityLabel,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.voucherLoadedAtLabel),
                        subtitle: Text(
                          DateFormat(
                            'd MMMM y',
                            'it_IT',
                          ).format(_voucherLoadedAt),
                        ),
                        trailing: const Icon(Icons.calendar_today_outlined),
                        onTap: _pickVoucherLoadedAt,
                      ),
                    ],
                  ],
                  if (_isEditMode && _type != WalletType.mealVoucher) ...[
                    const SizedBox(height: AppSpacing.md),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.tune),
                      title: Text(l10n.accountBalanceAdjustmentAction),
                      subtitle: _existing != null
                          ? Text(_existing!.balance.format())
                          : null,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _adjustBalance,
                    ),
                    if (_openingBalanceTransaction != null)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.edit_calendar_outlined),
                        title: Text(l10n.editOpeningBalanceSheetTitle),
                        subtitle: Text(
                          _openingBalanceTransaction!.amount.format(),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _editOpeningBalance,
                      ),
                  ],
                  if (_isEditMode && _type == WalletType.mealVoucher) ...[
                    const SizedBox(height: AppSpacing.md),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.restaurant_outlined),
                      title: Text(l10n.voucherLotsAction),
                      subtitle: _existing != null
                          ? Text(_existing!.balance.format())
                          : null,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              VoucherLotsScreen(walletId: widget.editWalletId!),
                        ),
                      ),
                    ),
                  ],
                  if (_isEditMode && _type == WalletType.cash) ...[
                    const SizedBox(height: AppSpacing.md),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.payments_outlined),
                      title: Text(l10n.walletDenominationsAction),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => WalletDenominationsScreen(
                            walletId: widget.editWalletId!,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      presentError(_error!, l10n).message,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    onPressed: _isSaving ? null : _submit,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.saveWalletAction),
                  ),
                ],
              ),
            ),
    );
  }

  String _monthName(int month) =>
      DateFormat.MMMM('it_IT').format(DateTime(2024, month));
}
