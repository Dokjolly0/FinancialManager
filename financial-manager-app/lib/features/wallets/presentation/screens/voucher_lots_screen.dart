import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/errors/error_presentation.dart';
import '../../../../core/formatting/money.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/providers.dart';
import '../../domain/models/voucher_lot.dart';
import '../../domain/models/wallet.dart';
import '../widgets/voucher_credit_sheet.dart';

/// Active/expiring-soon/expired breakdown of a MEAL_VOUCHER wallet's lots
/// (migration 0025), plus the entry points to add or remove vouchers
/// outside of a purchase. Mirrors WalletDenominationsScreen's shape, but
/// lots are ledger-backed (never purely informational) so this screen is
/// read-only over them — mutations go through VoucherCreditSheet.
class VoucherLotsScreen extends ConsumerStatefulWidget {
  const VoucherLotsScreen({super.key, required this.walletId});

  final String walletId;

  @override
  ConsumerState<VoucherLotsScreen> createState() => _VoucherLotsScreenState();
}

class _VoucherLotsScreenState extends ConsumerState<VoucherLotsScreen> {
  Wallet? _wallet;
  List<VoucherLot>? _lots;
  bool _isLoading = true;
  AppError? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(walletRepositoryProvider);
      final wallet = await repo.getWallet(widget.walletId);
      final lots = await repo.getVoucherLots(widget.walletId);
      if (!mounted) return;
      setState(() {
        _wallet = wallet;
        _lots = lots;
        _isLoading = false;
      });
    } on AppError catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e;
      });
    }
  }

  Future<void> _openCreditSheet(bool isAddition) async {
    final wallet = _wallet;
    if (wallet == null || wallet.voucherUnitValueMinor == null) return;
    final changed = await VoucherCreditSheet.show(
      context,
      walletId: widget.walletId,
      isAddition: isAddition,
      unitValueMinor: wallet.voucherUnitValueMinor!,
      currency: wallet.balance.currency,
    );
    if (changed && mounted) await _load();
  }

  Widget _lotTile(
    BuildContext context,
    VoucherLot lot, {
    bool expired = false,
  }) {
    final l10n = AppLocalizations.of(context);
    final wallet = _wallet!;
    final quantity = expired ? lot.quantityExpired : lot.quantityRemaining;
    final value = Money(
      minorUnits: quantity * wallet.voucherUnitValueMinor!,
      currency: wallet.balance.currency,
    );
    return ListTile(
      leading: Icon(
        expired ? Icons.event_busy_outlined : Icons.confirmation_num_outlined,
        color: expired ? Theme.of(context).colorScheme.error : null,
      ),
      title: Text(l10n.voucherLotQuantityLabel(quantity)),
      subtitle: Text(
        expired
            ? l10n.voucherLotExpiredOnLabel(
                DateFormat('d MMMM y', 'it_IT').format(lot.expiresAt),
              )
            : l10n.voucherLotExpiresOnLabel(
                DateFormat('d MMMM y', 'it_IT').format(lot.expiresAt),
              ),
      ),
      trailing: Text(value.format()),
      onTap: expired && lot.expiredByTransactionId != null
          ? () => context.push(
              AppRoutes.transactionDetail(lot.expiredByTransactionId!),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lots = _lots;

    List<VoucherLot> active = const [];
    List<VoucherLot> expiringSoon = const [];
    List<VoucherLot> expired = const [];
    if (lots != null) {
      active = lots.where((l) => l.isActive).toList()
        ..sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
      expiringSoon = active
          .where((l) => l.isExpiringWithin(voucherExpiringSoonWindow))
          .toList();
      expired = lots.where((l) => l.isExpiredHistory).toList()
        ..sort((a, b) => b.expiresAt.compareTo(a.expiresAt));
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.voucherLotsScreenTitle)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : lots == null
          ? Center(
              child: Text(
                _error != null
                    ? presentError(_error!, l10n).message
                    : l10n.voucherLotsLoadError,
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                children: [
                  if (expiringSoon.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.md,
                        AppSpacing.md,
                        AppSpacing.xs,
                      ),
                      child: Text(
                        l10n.voucherExpiringSoonSectionTitle,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                    for (final lot in expiringSoon) _lotTile(context, lot),
                  ],
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.xs,
                    ),
                    child: Text(
                      l10n.voucherActiveSectionTitle,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  if (active.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: Text(l10n.voucherActiveEmptyMessage),
                    )
                  else
                    for (final lot in active) _lotTile(context, lot),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.xs,
                    ),
                    child: Text(
                      l10n.voucherExpiredSectionTitle,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  if (expired.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: Text(l10n.voucherExpiredEmptyMessage),
                    )
                  else
                    for (final lot in expired)
                      _lotTile(context, lot, expired: true),
                ],
              ),
            ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _wallet == null
                    ? null
                    : () => _openCreditSheet(false),
                child: Text(l10n.removeVouchersAction),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: FilledButton(
                onPressed: _wallet == null
                    ? null
                    : () => _openCreditSheet(true),
                child: Text(l10n.addVouchersAction),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
