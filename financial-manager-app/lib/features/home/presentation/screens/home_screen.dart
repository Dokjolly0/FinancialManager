import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../app/session/current_user_provider.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/error_presentation.dart';
import '../../../../core/formatting/color_hex.dart';
import '../../../../core/widgets/balance_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/inline_error.dart';
import '../../../../core/widgets/skeleton_list.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../media/data/providers.dart';
import '../../../transactions/presentation/widgets/transaction_tile.dart';
import '../../../wallets/presentation/widgets/wallet_icon_data.dart';
import '../view_models/home_controller.dart';

/// Home (plan.md section 7.5): balance, quick add actions, recent
/// operations. "Questo mese" summary is deferred to the reports feature
/// (Fase 7) — it needs the same aggregate-query infrastructure reports
/// will build, and duplicating a rough version here isn't worth it.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeControllerProvider);
    final user = ref.watch(currentUserProvider);
    final controller = ref.read(homeControllerProvider.notifier);
    final mediaRepo = ref.read(mediaRepositoryProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(user == null ? 'Ciao' : 'Ciao, ${user.firstName}'),
      ),
      body: RefreshIndicator(
        onRefresh: controller.refresh,
        child: state.isLoading
            ? const SkeletonList()
            : state.error != null && state.wallets.isEmpty
            ? InlineError(
                message: presentError(state.error!, l10n).message,
                onRetry: controller.refresh,
              )
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  BalanceCard(
                    balance: state.totalBalance,
                    label: l10n.walletsTotalBalanceLabel,
                    obscured: state.balanceObscured,
                    onToggleObscured: controller.toggleBalanceObscured,
                    onTap: () => context.push(AppRoutes.wallets),
                  ),
                  if (state.wallets.length > 1) ...[
                    const SizedBox(height: AppSpacing.sm),
                    for (final wallet in state.wallets)
                      Card(
                        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: colorFromHex(wallet.color),
                            child: Icon(
                              iconForWalletKey(wallet.icon),
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                          title: Text(wallet.name),
                          trailing: Text(
                            state.balanceObscured
                                ? '••••••'
                                : wallet.balance.format(),
                          ),
                          onTap: () => context.push(AppRoutes.wallets),
                        ),
                      ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () =>
                              context.push(AppRoutes.transactionsNew),
                          icon: const Icon(Icons.add),
                          label: const Text('Entrata/Uscita'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Ultime operazioni',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      TextButton(
                        onPressed: () => context.go(AppRoutes.history),
                        child: const Text('Vedi tutte'),
                      ),
                    ],
                  ),
                  if (state.recentTransactions.isEmpty)
                    const EmptyState(
                      message: 'Nessuna operazione ancora registrata.',
                    )
                  else
                    ...state.recentTransactions.map(
                      (t) => TransactionTile(
                        transaction: t,
                        imageUrl: t.mediaId == null
                            ? null
                            : mediaRepo.contentUrl(t.mediaId!),
                        imageHeaders: mediaRepo.authHeaders(),
                        onTap: () =>
                            context.push(AppRoutes.transactionDetail(t.id)),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
