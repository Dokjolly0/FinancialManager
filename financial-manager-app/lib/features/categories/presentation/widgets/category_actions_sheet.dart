import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/errors/error_presentation.dart';
import '../../../../core/state/ledger_revision_provider.dart';
import '../../../../core/widgets/confirmation_sheet.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/providers.dart';
import '../../domain/models/category.dart';
import 'category_avatar.dart';
import 'category_edit_sheet.dart';

/// What can be done with one category, from a long press in the picker or
/// a tap in the Categories screen: edit or delete the user's own, hide or
/// show again a system one (plan.md section 14.7).
class CategoryActionsSheet extends StatelessWidget {
  const CategoryActionsSheet({super.key, required this.category});

  final Category category;

  /// Shows the sheet; completes once the chosen action is done.
  static Future<void> show(BuildContext context, Category category) async {
    final action = await showModalBottomSheet<_CategoryAction>(
      context: context,
      // See ConfirmationSheet's useRootNavigator comment.
      useRootNavigator: true,
      showDragHandle: true,
      builder: (context) => CategoryActionsSheet(category: category),
    );
    if (action == null || !context.mounted) return;
    final container = ProviderScope.containerOf(context, listen: false);
    switch (action) {
      case _CategoryAction.edit:
        await CategoryEditSheet.show(context, category: category);
      case _CategoryAction.delete:
        await _confirmAndDelete(context, container, category);
      case _CategoryAction.hide:
        await _setHidden(context, container, category, hidden: true);
      case _CategoryAction.unhide:
        await _setHidden(context, container, category, hidden: false);
    }
  }

  static Future<void> _confirmAndDelete(
    BuildContext context,
    ProviderContainer container,
    Category category,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await ConfirmationSheet.show(
      context,
      title: l10n.deleteCategoryConfirmTitle(category.name),
      message: category.usageCount > 0
          ? l10n.deleteCategoryInUseMessage(category.usageCount)
          : l10n.deleteCategoryUnusedMessage,
      confirmLabel: l10n.commonDelete,
      isDestructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await _run(context, container, () async {
      await container
          .read(categoryRepositoryProvider)
          .deleteCategory(category.id);
      // Its transactions are now uncategorized: history and reports refetch.
      container.read(ledgerRevisionProvider.notifier).state++;
    });
  }

  static Future<void> _setHidden(
    BuildContext context,
    ProviderContainer container,
    Category category, {
    required bool hidden,
  }) {
    return _run(
      context,
      container,
      () => container
          .read(categoryRepositoryProvider)
          .setCategoryHidden(category.id, hidden: hidden),
    );
  }

  /// Runs [action], refreshes the categories, and shows any error.
  static Future<void> _run(
    BuildContext context,
    ProviderContainer container,
    Future<void> Function() action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      await action();
    } on AppError catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(presentError(e, l10n).message)),
      );
    }
    container.invalidate(categoriesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    void choose(_CategoryAction action) => Navigator.of(context).pop(action);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: CategoryAvatar(category: category),
              title: Text(
                category.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: Text(l10n.categoryUsageCount(category.usageCount)),
            ),
            const Divider(),
            if (category.isSystem) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: Text(
                  l10n.systemCategoryActionsHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              if (category.hidden)
                ListTile(
                  leading: const Icon(Icons.visibility_outlined),
                  title: Text(l10n.unhideCategoryAction),
                  onTap: () => choose(_CategoryAction.unhide),
                )
              else
                ListTile(
                  leading: const Icon(Icons.visibility_off_outlined),
                  title: Text(l10n.hideCategoryAction),
                  onTap: () => choose(_CategoryAction.hide),
                ),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(l10n.editCategoryAction),
                onTap: () => choose(_CategoryAction.edit),
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  l10n.commonDelete,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () => choose(_CategoryAction.delete),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _CategoryAction { edit, delete, hide, unhide }
