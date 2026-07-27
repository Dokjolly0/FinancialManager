import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/formatting/color_hex.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/providers.dart';
import '../../domain/models/wallet.dart';
import 'wallet_icon_data.dart';

/// Bottom sheet listing every active wallet, used by the transaction form's
/// wallet selector and the transfer sheet's source/destination pickers
/// (plan.md: "poter scegliere per ogni nuova spesa a che portafoglio
/// scalarla"). Returns the selected [Wallet], or `null` if dismissed.
class WalletPickerSheet extends ConsumerWidget {
  const WalletPickerSheet({super.key, this.excludeWalletId});

  /// Hides one wallet from the list — used by the transfer sheet so the
  /// destination picker can't offer the wallet already chosen as source.
  final String? excludeWalletId;

  static Future<Wallet?> show(BuildContext context, {String? excludeWalletId}) {
    return showModalBottomSheet<Wallet?>(
      context: context,
      // See ConfirmationSheet's useRootNavigator comment — otherwise
      // AppShell's centerDocked FAB sits above this sheet's own content.
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => WalletPickerSheet(excludeWalletId: excludeWalletId),
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
                      .toList();
                  return ListView(
                    shrinkWrap: true,
                    children: [
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
