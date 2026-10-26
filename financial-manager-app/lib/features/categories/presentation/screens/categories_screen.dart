import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/inline_error.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/providers.dart';
import '../../domain/models/category.dart';
import '../../domain/models/category_sort.dart';
import '../widgets/category_actions_sheet.dart';
import '../widgets/category_avatar.dart';
import '../widgets/category_edit_sheet.dart';
import '../widgets/category_sort_toggle.dart';

/// Category management (plan.md section 7.13), reached from Account:
/// expense and income categories in the shared A–Z / most used order, then
/// the hidden system ones. Tapping one opens its actions; the FAB creates
/// a new one.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final categoriesAsync = ref.watch(categoriesProvider);
    final sort = ref.watch(categorySortProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.categoriesScreenTitle)),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(categoriesProvider.future),
        child: categoriesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => InlineError(
            message: l10n.categoriesLoadError,
            onRetry: () => ref.invalidate(categoriesProvider),
          ),
          data: (categories) {
            final visible = sortCategories(
              categories.where((c) => !c.hidden),
              sort,
            );
            final hidden = sortCategories(
              categories.where((c) => c.hidden),
              sort,
            );
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                // Room for the FAB over the last row.
                AppSpacing.xl * 3,
              ),
              children: [
                const CategorySortToggle(),
                _Section(
                  title: l10n.categoryScopeDebit,
                  categories: visible
                      .where(
                        (c) =>
                            c.directionScope != CategoryDirectionScope.credit,
                      )
                      .toList(),
                ),
                _Section(
                  title: l10n.categoryScopeCredit,
                  categories: visible
                      .where(
                        (c) => c.directionScope != CategoryDirectionScope.debit,
                      )
                      .toList(),
                ),
                if (hidden.isNotEmpty)
                  _Section(
                    title: l10n.categoriesHiddenSection,
                    hint: l10n.categoriesHiddenHint,
                    categories: hidden,
                  ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => CategoryEditSheet.show(context),
        tooltip: l10n.newCategoryAction,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.categories, this.hint});

  final String title;
  final String? hint;
  final List<Category> categories;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.lg,
            bottom: AppSpacing.xs,
          ),
          child: Text(title, style: textTheme.titleSmall),
        ),
        if (hint != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(hint!, style: textTheme.bodySmall),
          ),
        Card(
          child: Column(
            children: [
              for (final category in categories)
                ListTile(
                  leading: CategoryAvatar(category: category),
                  title: Text(category.name),
                  subtitle: Text(
                    category.isSystem
                        ? '${l10n.categoryUsageCount(category.usageCount)} · '
                              '${l10n.categorySystemLabel}'
                        : l10n.categoryUsageCount(category.usageCount),
                  ),
                  trailing: const Icon(Icons.more_vert),
                  onTap: () => CategoryActionsSheet.show(context, category),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
