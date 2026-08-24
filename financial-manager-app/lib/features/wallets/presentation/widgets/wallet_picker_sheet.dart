import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/formatting/color_hex.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/providers.dart';
import '../../domain/models/wallet.dart';
import '../../domain/models/wallet_type.dart';
import 'wallet_icon_data.dart';

/// Bottom sheet listing every active wallet, used by the transaction form's
/// wallet selector and the transfer sheet's source/destination pickers
/// (plan.md: "poter scegliere per ogni nuova spesa a che portafoglio
/// scalarla"). Returns the selected [Wallet], or `null` if dismissed.
class WalletPickerSheet extends ConsumerWidget {
  const WalletPickerSheet({
    super.key,
    this.excludeWalletId,
    this.showAllWalletsOption = false,
    this.typeFilter,
  });

  /// Hides one wallet from the list — used by the transfer sheet so the
  /// destination picker can't offer the wallet already chosen as source.
  final String? excludeWalletId;

  /// Prepends an "all wallets" tile that pops `null` — used by the history
  /// filters sheet, where no wallet selected means "every wallet" (unlike
  /// the transaction form/transfer sheet, where a wallet is required).
  final bool showAllWalletsOption;

  /// Restricts the list to wallets of these types — used by
  /// VoucherExpenseSheet, whose voucher-wallet picker only makes sense over
  /// MEAL_VOUCHER wallets, and whose "other wallet" picker excludes them.
  /// `null` means unfiltered.
  final Set<WalletType>? typeFilter;

  static Future<Wallet?> show(
    BuildContext context, {
    String? excludeWalletId,
    bool showAllWalletsOption = false,
    Set<WalletType>? typeFilter,
  }) {
    return showModalBottomSheet<Wallet?>(
      context: context,
      // See ConfirmationSheet's useRootNavigator comment — otherwise
      // AppShell's centerDocked FAB sits above this sheet's own content.
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => WalletPickerSheet(
        excludeWalletId: excludeWalletId,
        showAllWalletsOption: showAllWalletsOption,
        typeFilter: typeFilter,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletsAsync = ref.watch(walletsListProvider);
    final l10n = AppLocalizations.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Text(
                l10n.walletPickerTitle,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
            Flexible(
              child: walletsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, _) => Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(l10n.walletsLoadError),
                ),
                data: (wallets) {
                  final visible = wallets
                      .where((w) => w.id != excludeWalletId)
                      .where((w) => typeFilter?.contains(w.type) ?? true)
                      .toList();
                  return ListView(
                    shrinkWrap: true,
                    children: [
                      if (showAllWalletsOption)
                        ListTile(
                          leading: const Icon(Icons.list_alt_outlined),
                          title: Text(l10n.allWalletsLabel),
                          onTap: () => Navigator.of(context).pop(null),
                        ),
                      for (final wallet in visible)
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: colorFromHex(wallet.color),
                            child: Icon(
                              iconForWalletKey(wallet.icon),
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          title: Text(wallet.name),
                          subtitle: Text(wallet.balance.format()),
                          onTap: () => Navigator.of(context).pop(wallet),
                        ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}
