import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/error_presentation.dart';
import '../../../../core/formatting/money.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/inline_error.dart';
import '../../../../core/widgets/skeleton_list.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../categories/data/providers.dart';
import '../../../categories/domain/models/category.dart';
import '../../../media/data/providers.dart';
import '../../../transactions/presentation/widgets/transaction_tile.dart';
import '../../domain/day_group.dart';
import '../view_models/history_controller.dart';
import '../widgets/history_filters_sheet.dart';

/// Cronologia (plan.md section 7.9): searchable, filterable, cursor-paginated
/// ledger list grouped by day.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_maybeLoadMore);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(historyControllerProvider.notifier).loadMore();
    }
  }

  Future<void> _openFilters() async {
    final controller = ref.read(historyControllerProvider.notifier);
    final current = ref.read(historyControllerProvider).filter;
    final applied = await HistoryFiltersSheet.show(
      context,
      initialFilter: current,
    );
    if (applied != null) {
      controller.applyFilter(applied);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(historyControllerProvider);
    final controller = ref.read(historyControllerProvider.notifier);
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final mediaRepo = ref.read(mediaRepositoryProvider);
    final l10n = AppLocalizations.of(context);
    final dayGroups = DayGroup.group(state.transactions);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cronologia'),
        actions: [
          IconButton(
            icon: Badge(
              label: Text('${state.filter.activeCount}'),
              isLabelVisible: state.hasActiveFilters,
              child: const Icon(Icons.filter_list),
            ),
            tooltip: 'Filtri',
            onPressed: _openFilters,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Cerca per titolo',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: controller.setSearchQuery,
            ),
          ),
          Expanded(
            child: state.isLoading
                ? const SkeletonList()
                : state.error != null && state.transactions.isEmpty
                ? InlineError(
                    message: presentError(state.error!, l10n).message,
                    onRetry: controller.refresh,
                  )
                : state.transactions.isEmpty
                ? EmptyState(
                    message: state.hasActiveFilters
                        ? 'Nessuna operazione corrisponde ai filtri.'
                        : 'Nessuna operazione ancora registrata.',
                  )
                : RefreshIndicator(
                    onRefresh: controller.refresh,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                      itemCount: dayGroups.length + 1,
                      itemBuilder: (context, index) {
                        if (index == dayGroups.length) {
                          return state.isLoadingMore
                              ? const Padding(
                                  padding: EdgeInsets.all(AppSpacing.md),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              : const SizedBox.shrink();
                        }

                        final group = dayGroups[index];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.md,
                                AppSpacing.sm,
                                AppSpacing.md,
                                AppSpacing.xs,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _dayLabel(group.day),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelLarge,
                                  ),
                                  Text(
                                    Money(
                                      minorUnits: group.netMinor,
                                      currency: 'EUR',
                                    ).format(),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelMedium,
                                  ),
                                ],
                              ),
                            ),
                            for (final transaction in group.transactions)
                              TransactionTile(
                                transaction: transaction,
                                categoryName: _categoryName(
                                  categories,
                                  transaction.categoryId,
                                ),
                                imageUrl: transaction.mediaId == null
                                    ? null
                                    : mediaRepo.contentUrl(
                                        transaction.mediaId!,
                                      ),
                                imageHeaders: mediaRepo.authHeaders(),
                                onTap: () => context.push(
                                  AppRoutes.transactionDetail(transaction.id),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String? _categoryName(List<Category> categories, String? categoryId) {
    if (categoryId == null) return null;
    final matches = categories.where((c) => c.id == categoryId);
    return matches.isEmpty ? null : matches.first.name;
  }

  String _dayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (day == today) return 'Oggi';
    if (day == yesterday) return 'Ieri';
    return DateFormat('EEEE d MMMM', 'it_IT').format(day);
  }
}
