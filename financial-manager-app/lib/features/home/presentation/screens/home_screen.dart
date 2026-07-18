import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../app/session/current_user_provider.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/balance_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/inline_error.dart';
import '../../../../core/widgets/skeleton_list.dart';
import '../../../transactions/presentation/widgets/transaction_tile.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: Text(user == null ? 'Ciao' : 'Ciao, ${user.firstName}'),
      ),
      body: RefreshIndicator(
        onRefresh: controller.refresh,
        child: state.isLoading
            ? const SkeletonList()
            : state.error != null && state.wallet == null
            ? InlineError(message: state.error!, onRetry: controller.refresh)
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  if (state.wallet != null)
                    BalanceCard(
                      balance: state.wallet!.balance,
                      obscured: state.balanceObscured,
                      onToggleObscured: controller.toggleBalanceObscured,
                    ),
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
