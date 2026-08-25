import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/error_presentation.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/inline_error.dart';
import '../../../../core/widgets/skeleton_list.dart';
import '../../../../l10n/app_localizations.dart';
import '../view_models/payment_groups_controller.dart';

/// "Pagamenti collegati" (plan.md linked-transactions feature): every group
/// of 2+ transactions the user has linked as installments of the same
/// logical expense (e.g. an acconto and a saldo), with their combined
/// total. Tapping a row opens the group's representative (earliest member)
/// in the ordinary transaction detail screen, which shows every member and
/// lets the user drill into any of them.
class PaymentGroupsScreen extends ConsumerWidget {
  const PaymentGroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(paymentGroupsControllerProvider);
    final controller = ref.read(paymentGroupsControllerProvider.notifier);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.linkedPaymentsSectionTitle)),
      body: state.isLoading
          ? const SkeletonList()
          : state.error != null && state.groups.isEmpty
          ? InlineError(
              message: presentError(state.error!, l10n).message,
              onRetry: controller.refresh,
            )
          : state.groups.isEmpty
          ? EmptyState(message: l10n.linkedPaymentsEmptyStateMessage)
          : RefreshIndicator(
              onRefresh: controller.refresh,
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                itemCount: state.groups.length,
                itemBuilder: (context, index) {
                  final group = state.groups[index];
                  return ListTile(
                    leading: const Icon(Icons.link),
                    title: Text(
                      group.representativeTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      l10n.linkedPaymentsMemberCountLabel(group.memberCount),
                    ),
                    trailing: Text(
                      group.netAmount.format(),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    onTap: () => context.push(
                      AppRoutes.transactionDetail(
                        group.representativeTransactionId,
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
