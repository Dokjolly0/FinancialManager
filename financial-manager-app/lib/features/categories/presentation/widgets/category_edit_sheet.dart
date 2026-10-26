import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/errors/error_presentation.dart';
import '../../../../core/formatting/color_hex.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../wallets/presentation/widgets/wallet_icon_data.dart';
import '../../data/providers.dart';
import '../../domain/models/category.dart';

/// Creates a category, or edits one of the user's own when [category] is
/// set: name, which directions it's used for, and color. Returns the saved
/// [Category], or `null` if dismissed.
class CategoryEditSheet extends ConsumerStatefulWidget {
  const CategoryEditSheet({
    super.key,
    this.category,
    this.initialScope = CategoryDirectionScope.debit,
  });

  final Category? category;
  final CategoryDirectionScope initialScope;

  static Future<Category?> show(
    BuildContext context, {
    Category? category,
    CategoryDirectionScope initialScope = CategoryDirectionScope.debit,
  }) {
    return showModalBottomSheet<Category?>(
      context: context,
      // See ConfirmationSheet's useRootNavigator comment.
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) =>
          CategoryEditSheet(category: category, initialScope: initialScope),
    );
  }

  @override
  ConsumerState<CategoryEditSheet> createState() => _CategoryEditSheetState();
}

class _CategoryEditSheetState extends ConsumerState<CategoryEditSheet> {
  late final _nameController = TextEditingController(
    text: widget.category?.name ?? '',
  );
  late CategoryDirectionScope _scope =
      widget.category?.directionScope ?? widget.initialScope;
  late String? _color = widget.category?.color?.toUpperCase();
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });
    final repository = ref.read(categoryRepositoryProvider);
    try {
      final existing = widget.category;
      final saved = existing == null
          ? await repository.createCategory(
              name: name,
              directionScope: _scope,
              color: _color,
            )
          : await repository.updateCategory(
              id: existing.id,
              name: name,
              directionScope: _scope,
              color: _color,
            );
      ref.invalidate(categoriesProvider);
      if (mounted) Navigator.of(context).pop(saved);
    } on AppError catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _error = presentError(e, AppLocalizations.of(context)).message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.category == null
                    ? l10n.newCategoryAction
                    : l10n.editCategoryTitle,
                style: textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _nameController,
                autofocus: widget.category == null,
                maxLength: 80,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l10n.categoryNameLabel,
                  errorText: _error,
                ),
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.categoryScopeLabel, style: textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.xs),
              SegmentedButton<CategoryDirectionScope>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: CategoryDirectionScope.debit,
                    label: Text(l10n.categoryScopeDebit),
                  ),
                  ButtonSegment(
                    value: CategoryDirectionScope.credit,
                    label: Text(l10n.categoryScopeCredit),
                  ),
                  ButtonSegment(
                    value: CategoryDirectionScope.both,
                    label: Text(l10n.categoryScopeBoth),
                  ),
                ],
                selected: {_scope},
                onSelectionChanged: (selection) =>
                    setState(() => _scope = selection.single),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.categoryColorLabel, style: textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  _ColorChoice(
                    color: null,
                    tooltip: l10n.categoryNoColor,
                    isSelected: _color == null,
                    onTap: () => setState(() => _color = null),
                  ),
                  for (final color in walletColorChoices)
                    _ColorChoice(
                      color: color,
                      isSelected: _color == colorToHex(color),
                      onTap: () => setState(() => _color = colorToHex(color)),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.commonSave),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One swatch of the color row; a null [color] is "no color".
class _ColorChoice extends StatelessWidget {
  const _ColorChoice({
    required this.color,
    required this.isSelected,
    required this.onTap,
    this.tooltip,
  });

  final Color? color;
  final bool isSelected;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final swatch = InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color ?? colorScheme.secondaryContainer,
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(color: colorScheme.onSurface, width: 2)
              : null,
        ),
        child: color == null
            ? Icon(Icons.block, size: 18, color: colorScheme.onSurfaceVariant)
            : null,
      ),
    );
    return tooltip == null ? swatch : Tooltip(message: tooltip, child: swatch);
  }
}
