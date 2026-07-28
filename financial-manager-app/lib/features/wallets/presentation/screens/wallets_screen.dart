import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/formatting/color_hex.dart';
import '../../../../core/formatting/money.dart';
import '../../../../core/widgets/inline_error.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/providers.dart';
import '../../domain/models/wallet.dart';
import '../widgets/transfer_sheet.dart';
import '../widgets/wallet_icon_data.dart';

/// Wallet management screen (plan.md multi-wallet extension): aggregate
/// total up top, active wallets below — reached from the Account hub's
/// teaser card. Archived wallets simply drop off this list (their history
/// stays in reports/export; plan.md's archive-only deletion).
class WalletsScreen extends ConsumerWidget {
  const WalletsScreen({super.key});

  Money _aggregateBalance(List<Wallet> wallets) {
    if (wallets.isEmpty) return Money.zeroEur;
    return wallets.map((w) => w.balance).reduce((a, b) => a + b);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletsAsync = ref.watch(walletsListProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.walletsScreenTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: l10n.transferAction,
            onPressed: () async {
              final completed = await TransferSheet.show(context);
              if (completed) ref.invalidate(walletsListProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(walletsListProvider),
        child: walletsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => InlineError(
            message: l10n.walletsLoadError,
            onRetry: () => ref.invalidate(walletsListProvider),
          ),
          data: (wallets) {
            if (wallets.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: AppSpacing.xl),
                  Center(child: Text(l10n.walletsEmptyStateMessage)),
                ],
              );
            }
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.walletsTotalBalanceLabel,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _aggregateBalance(wallets).format(),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                for (final wallet in wallets)
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: colorFromHex(wallet.color),
                        child: Icon(
                          iconForWalletKey(wallet.icon),
                          color: Colors.white,
                        ),
                      ),
                      title: Text(wallet.name),
                      subtitle: Text(wallet.balance.format()),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final changed = await context.push<bool>(
                          AppRoutes.walletEdit(wallet.id),
                        );
                        if (changed == true)
                          ref.invalidate(walletsListProvider);
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await context.push<bool>(AppRoutes.walletsNew);
          if (created == true) ref.invalidate(walletsListProvider);
        },
        tooltip: l10n.addWalletAction,
        child: const Icon(Icons.add),
      ),
    );
  }
}
