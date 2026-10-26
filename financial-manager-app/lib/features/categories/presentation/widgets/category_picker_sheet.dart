import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../transactions/domain/models/transaction_direction.dart';
import '../../data/providers.dart';
import '../../domain/models/category.dart';
import '../../domain/models/category_sort.dart';
import 'category_actions_sheet.dart';
import 'category_avatar.dart';
import 'category_sort_toggle.dart';

/// Bottom sheet listing every category visible to the user, filtered to
/// those valid for [direction] (plan.md section 7.6) — or every category
/// regardless of direction when [direction] is `null`. The order follows
/// the shared A–Z / most used toggle, and a long press opens the
/// category's actions (edit, delete, hide).
///
/// Two modes:
/// - [show], for a transaction: hidden categories are left out, a new one
///   can be created. Returns the selected [Category], or `null` if
///   dismissed / "Nessuna categoria" was chosen.
/// - [showFilter], for the history filters: "Tutte le categorie", "Senza
///   categoria" ([uncategorizedFilterId]) and every category, hidden ones
///   included (old transactions may use them); no creation.
class CategoryPickerSheet extends ConsumerStatefulWidget {
  const CategoryPickerSheet({
    super.key,
    this.direction,
    this.filterMode = false,
  });

  final TransactionDirection? direction;
  final bool filterMode;

  static Future<Category?> show(
    BuildContext context, {
    TransactionDirection? direction,
  }) async {
    final result = await _showSheet(
      context,
      CategoryPickerSheet(direction: direction),
    );
    return result is Category ? result : null;
  }

  /// The chosen filter: `null` if dismissed, otherwise a record whose
  /// `categoryId` is a category id, [uncategorizedFilterId], or `null` for
  /// every category.
  static Future<({String? categoryId})?> showFilter(
    BuildContext context,
  ) async {
    final result = await _showSheet(
      context,
      const CategoryPickerSheet(filterMode: true),
    );
    return result is ({String? categoryId}) ? result : null;
  }

  static Future<Object?> _showSheet(BuildContext context, Widget sheet) {
    return showModalBottomSheet<Object?>(
      context: context,
      // See ConfirmationSheet's useRootNavigator comment — otherwise
      // AppShell's centerDocked FAB sits above this sheet's own buttons.
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => sheet,
    );
  }

  @override
  ConsumerState<CategoryPickerSheet> createState() =>
      _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends ConsumerState<CategoryPickerSheet> {
  bool _showCreateForm = false;
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();
  String _query = '';
  bool _isCreating = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Closes with [category] (null: no category) in the shape of the mode.
  void _pick(Category? category) {
    Navigator.of(
      context,
    ).pop(widget.filterMode ? (categoryId: category?.id) : category);
  }

  Future<void> _createCategory() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _isCreating = true;
      _error = null;
    });
    try {
      final directionScope = widget.direction == TransactionDirection.credit
          ? CategoryDirectionScope.credit
          : CategoryDirectionScope.debit;
      final created = await ref
          .read(categoryRepositoryProvider)
          .createCategory(name: name, directionScope: directionScope);
      ref.invalidate(categoriesProvider);
      if (mounted) Navigator.of(context).pop(created);
    } catch (_) {
      if (mounted) {
        setState(() {
          _isCreating = false;
          _error = AppLocalizations.of(context).createCategoryError;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final l10n = AppLocalizations.of(context);

    // Fixed height (instead of sizing to the content) so filtering doesn't
    // shrink the sheet down behind the keyboard: the search field stays at
    // the top and the results fill the space down to the keyboard.
    final mediaQuery = MediaQuery.of(context);
    final keyboardHeight = mediaQuery.viewInsets.bottom;
    final sheetHeight = math.min(
      mediaQuery.size.height * 0.8,
      mediaQuery.size.height - keyboardHeight - mediaQuery.padding.top,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: SafeArea(
        child: SizedBox(
          height: sheetHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Text(
                    l10n.categoryPickerTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: l10n.categorySearchHint,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                            ),
                    ),
                    onChanged: (value) =>
                        setState(() => _query = value.trim().toLowerCase()),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.xs),
                  child: CategorySortToggle(),
                ),
                Expanded(
                  child: categoriesAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, _) => Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text(l10n.categoriesLoadError),
                    ),
                    data: (categories) {
                      final direction = widget.direction;
                      final visible = sortCategories(
                        categories.where(
                          (c) =>
                              (widget.filterMode || !c.hidden) &&
                              (direction == null || c.matches(direction)) &&
                              c.name.toLowerCase().contains(_query),
                        ),
                        ref.watch(categorySortProvider),
                      );
                      return ListView(
                        children: [
                          if (_query.isEmpty && widget.filterMode) ...[
                            ListTile(
                              leading: const Icon(Icons.label_outline),
                              title: Text(l10n.allCategoriesLabel),
                              onTap: () => _pick(null),
                            ),
                            ListTile(
                              leading: const Icon(Icons.block_outlined),
                              title: Text(l10n.uncategorizedFilterLabel),
                              onTap: () => Navigator.of(
                                context,
                              ).pop((categoryId: uncategorizedFilterId)),
                            ),
                          ] else if (_query.isEmpty)
                            ListTile(
                              leading: const Icon(Icons.block_outlined),
                              title: Text(l10n.noCategoryLabel),
                              onTap: () => _pick(null),
                            )
                          else if (visible.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              child: Text(
                                l10n.categorySearchNoResults,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          for (final category in visible)
                            ListTile(
                              leading: CategoryAvatar(category: category),
                              title: Text(category.name),
                              onTap: () => _pick(category),
                              onLongPress: () =>
                                  CategoryActionsSheet.show(context, category),
                            ),
                        ],
                      );
                    },
                  ),
                ),
                const Divider(height: AppSpacing.md),
                if (widget.filterMode)
                  const SizedBox(height: AppSpacing.md)
                else if (_showCreateForm)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _nameController,
                          autofocus: true,
                          decoration: InputDecoration(
                            labelText: l10n.newCategoryNameLabel,
                            errorText: _error,
                          ),
                          onSubmitted: (_) => _createCategory(),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        FilledButton(
                          onPressed: _isCreating ? null : _createCategory,
                          child: _isCreating
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(l10n.createAndSelectAction),
                        ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                    child: OutlinedButton.icon(
                      // Prefill with the search text, so searching for a missing
                      // category and then creating it doesn't mean retyping it.
                      onPressed: () => setState(() {
                        _nameController.text = _searchController.text.trim();
                        _showCreateForm = true;
                      }),
                      icon: const Icon(Icons.add),
                      label: Text(l10n.newCategoryAction),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
