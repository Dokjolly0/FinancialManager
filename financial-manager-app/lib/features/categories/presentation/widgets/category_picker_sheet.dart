import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../transactions/domain/models/transaction_direction.dart';
import '../../data/providers.dart';
import '../../domain/models/category.dart';

/// Bottom sheet listing every category visible to the user, filtered to
/// those valid for [direction] (plan.md section 7.6) — or every category
/// regardless of direction when [direction] is `null` (used by the history
/// filters, which aren't tied to a single direction). Returns the selected
/// [Category], or `null` if dismissed / "Nessuna categoria" was chosen.
class CategoryPickerSheet extends ConsumerStatefulWidget {
  const CategoryPickerSheet({
    super.key,
    this.direction,
    this.allowCreate = true,
  });

  final TransactionDirection? direction;
  final bool allowCreate;

  static Future<Category?> show(
    BuildContext context, {
    TransactionDirection? direction,
    bool allowCreate = true,
  }) {
    return showModalBottomSheet<Category?>(
      context: context,
      // See ConfirmationSheet's useRootNavigator comment — otherwise
      // AppShell's centerDocked FAB sits above this sheet's own buttons.
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) =>
          CategoryPickerSheet(direction: direction, allowCreate: allowCreate),
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
                      final visible =
                          categories
                              .where(
                                (c) =>
                                    (direction == null ||
                                        c.matches(direction)) &&
                                    c.name.toLowerCase().contains(_query),
                              )
                              .toList()
                            ..sort(
                              (a, b) => a.sortOrder.compareTo(b.sortOrder),
                            );
                      return ListView(
                        children: [
                          if (_query.isEmpty)
                            ListTile(
                              leading: const Icon(Icons.block_outlined),
                              title: Text(l10n.noCategoryLabel),
                              onTap: () => Navigator.of(context).pop(null),
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
                              leading: CircleAvatar(
                                backgroundColor: _colorFor(context, category),
                                child: Text(
                                  category.name.isEmpty
                                      ? '?'
                                      : category.name[0].toUpperCase(),
                                ),
                              ),
                              title: Text(category.name),
                              onTap: () => Navigator.of(context).pop(category),
                            ),
                        ],
                      );
                    },
                  ),
                ),
                const Divider(height: AppSpacing.md),
                if (!widget.allowCreate)
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

  Color _colorFor(BuildContext context, Category category) {
    if (category.color == null) {
      return Theme.of(context).colorScheme.secondaryContainer;
    }
    final hex = category.color!.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}
