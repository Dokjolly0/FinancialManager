import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/first_day_of_week_scope.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../account/presentation/view_models/account_providers.dart';
import '../../../categories/data/providers.dart';
import '../../../categories/presentation/widgets/category_picker_sheet.dart';
import '../../../transactions/domain/repositories/transaction_repository.dart';

/// Full-height filters sheet (plan.md section 7.9): title, amount range,
/// date range, type, category. Edits a local draft and only reports it back
/// via "Applica" — "Azzera" resets to an empty filter.
class HistoryFiltersSheet extends ConsumerStatefulWidget {
  const HistoryFiltersSheet({super.key, required this.initialFilter});

  final TransactionListFilter initialFilter;

  static Future<TransactionListFilter?> show(
    BuildContext context, {
    required TransactionListFilter initialFilter,
  }) {
    return showModalBottomSheet<TransactionListFilter?>(
      context: context,
      // See ConfirmationSheet's useRootNavigator comment — otherwise
      // AppShell's centerDocked FAB sits above this sheet's own buttons.
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => HistoryFiltersSheet(initialFilter: initialFilter),
    );
  }

  @override
  ConsumerState<HistoryFiltersSheet> createState() =>
      _HistoryFiltersSheetState();
}

class _HistoryFiltersSheetState extends ConsumerState<HistoryFiltersSheet> {
  late TransactionTypeFilter _type;
  late String? _categoryId;
  late final TextEditingController _titleController;
  late final TextEditingController _minController;
  late final TextEditingController _maxController;
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    final filter = widget.initialFilter;
    _type = filter.type;
    _categoryId = filter.categoryId;
    _titleController = TextEditingController(text: filter.title ?? '');
    _minController = TextEditingController(
      text: filter.amountMinMinor == null
          ? ''
          : (filter.amountMinMinor! / 100).toStringAsFixed(2),
    );
    _maxController = TextEditingController(
      text: filter.amountMaxMinor == null
          ? ''
          : (filter.amountMaxMinor! / 100).toStringAsFixed(2),
    );
    _from = filter.occurredFrom?.toLocal();
    _to = filter.occurredTo?.toLocal().subtract(const Duration(days: 1));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  int? _parseMinorUnits(String input) {
    final normalized = input.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    final value = double.tryParse(normalized);
    if (value == null || value < 0) return null;
    return (value * 100).round();
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final firstDayOfWeek =
        ref.read(accountProfileProvider).value?.firstDayOfWeek ?? 'monday';
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _from : _to) ?? now,
      firstDate: DateTime(2000),
      lastDate: now,
      builder: (context, child) =>
          firstDayOfWeekScope(context, child, firstDayOfWeek),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
      } else {
        _to = picked;
      }
    });
  }

  void _apply() {
    final amountMin = _parseMinorUnits(_minController.text);
    final amountMax = _parseMinorUnits(_maxController.text);
    final title = _titleController.text.trim();

    Navigator.of(context).pop(
      TransactionListFilter(
        type: _type,
        title: title.isEmpty ? null : title,
        categoryId: _categoryId,
        amountMinMinor: amountMin,
        amountMaxMinor: amountMax,
        // "Data finale" is inclusive of the whole day (plan.md section
        // 4.5: "I filtri date devono avere semantica inclusiva"), so the
        // exclusive upper bound sent to the backend is the start of the
        // *next* day.
        occurredFrom: _from == null
            ? null
            : DateTime(_from!.year, _from!.month, _from!.day).toUtc(),
        occurredTo: _to == null
            ? null
            : DateTime(
                _to!.year,
                _to!.month,
                _to!.day,
              ).add(const Duration(days: 1)).toUtc(),
      ),
    );
  }

  void _reset() {
    Navigator.of(context).pop(const TransactionListFilter());
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final matchingCategory = categories
        .where((c) => c.id == _categoryId)
        .toList();
    final selectedCategory = matchingCategory.isEmpty
        ? null
        : matchingCategory.first;
    final dateFormat = DateFormat('d MMM y', 'it_IT');
    final l10n = AppLocalizations.of(context);

    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.92,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.filtersTitle,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: ListView(
                  children: [
                    Text(
                      l10n.typeLabel,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      children: [
                        for (final option in TransactionTypeFilter.values)
                          ChoiceChip(
                            label: Text(_typeLabel(l10n, option)),
                            selected: _type == option,
                            onSelected: (_) => setState(() => _type = option),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: l10n.titleFieldLabel,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _minController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9,.]'),
                              ),
                            ],
                            decoration: InputDecoration(
                              labelText: l10n.minAmountLabel,
                              prefixText: '€ ',
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: TextField(
                            controller: _maxController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9,.]'),
                              ),
                            ],
                            decoration: InputDecoration(
                              labelText: l10n.maxAmountLabel,
                              prefixText: '€ ',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.startDateLabel),
                      subtitle: Text(
                        _from == null
                            ? l10n.anyLabel
                            : dateFormat.format(_from!),
                      ),
                      trailing: const Icon(Icons.calendar_today_outlined),
                      onTap: () => _pickDate(isFrom: true),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.endDateLabel),
                      subtitle: Text(
                        _to == null ? l10n.anyLabel : dateFormat.format(_to!),
                      ),
                      trailing: const Icon(Icons.calendar_today_outlined),
                      onTap: () => _pickDate(isFrom: false),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.label_outline),
                      title: Text(
                        selectedCategory?.name ?? l10n.allCategoriesLabel,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final selected = await CategoryPickerSheet.show(
                          context,
                          allowCreate: false,
                        );
                        setState(() => _categoryId = selected?.id);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _reset,
                      child: Text(l10n.resetAction),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: _apply,
                      child: Text(l10n.applyAction),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  String _typeLabel(AppLocalizations l10n, TransactionTypeFilter type) =>
      switch (type) {
        TransactionTypeFilter.all => l10n.typeFilterAll,
        TransactionTypeFilter.debit => l10n.debitsColumnLabel,
        TransactionTypeFilter.credit => l10n.creditsColumnLabel,
        TransactionTypeFilter.adjustments => l10n.typeFilterAdjustments,
      };
}
