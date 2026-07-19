import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/error_code_localizations.dart';
import '../../../../core/errors/error_presentation.dart';
import '../../../../core/widgets/amount_field.dart';
import '../../../../core/widgets/direction_segmented_control.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../categories/data/providers.dart';
import '../../../categories/domain/models/category.dart';
import '../../../categories/presentation/widgets/category_picker_sheet.dart';
import '../../../media/data/providers.dart';
import '../../../media/domain/models/media_asset.dart';
import '../../../media/presentation/widgets/image_picker_sheet.dart';
import '../../domain/models/transaction_direction.dart';
import '../view_models/transaction_form_controller.dart';
import '../widgets/title_autocomplete_field.dart';

/// New / edit operation (plan.md section 7.6, 7.11 — the same form).
class NewTransactionScreen extends ConsumerStatefulWidget {
  const NewTransactionScreen({super.key, this.editTransactionId});

  final String? editTransactionId;

  @override
  ConsumerState<NewTransactionScreen> createState() =>
      _NewTransactionScreenState();
}

class _NewTransactionScreenState extends ConsumerState<NewTransactionScreen> {
  final _amountController = TextEditingController();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _controllersSynced = false;

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime(BuildContext context, DateTime current) async {
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null) return;

    ref
        .read(
          transactionFormControllerProvider(widget.editTransactionId).notifier,
        )
        .setOccurredAt(
          DateTime(date.year, date.month, date.day, time.hour, time.minute),
        );
  }

  Future<void> _pickCategory(
    BuildContext context,
    TransactionDirection direction,
  ) async {
    final controller = ref.read(
      transactionFormControllerProvider(widget.editTransactionId).notifier,
    );
    final selected = await CategoryPickerSheet.show(
      context,
      direction: direction,
    );
    if (!mounted) return;
    controller.setCategory(selected);
  }

  Future<void> _pickImage(BuildContext context) async {
    final controller = ref.read(
      transactionFormControllerProvider(widget.editTransactionId).notifier,
    );
    final selected = await ImagePickerSheet.show(
      context,
      kind: MediaKind.transaction,
    );
    if (!mounted || selected == null) return;
    controller.setMedia(selected.id);
  }

  Future<void> _submit() async {
    final controller = ref.read(
      transactionFormControllerProvider(widget.editTransactionId).notifier,
    );
    controller.setTitle(_titleController.text);
    controller.setDescription(_descriptionController.text);
    controller.setAmountInput(_amountController.text);
    final ok = await controller.submit();
    if (ok && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      transactionFormControllerProvider(widget.editTransactionId),
    );
    final controller = ref.read(
      transactionFormControllerProvider(widget.editTransactionId).notifier,
    );
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
    final l10n = AppLocalizations.of(context);
    String? fieldError(String key) {
      final code = state.fieldErrors[key];
      return code == null ? null : localizeErrorCode(l10n, code);
    }

    if (!_controllersSynced && !state.isLoadingExisting) {
      _amountController.text = state.amountInput;
      _titleController.text = state.title;
      _descriptionController.text = state.description;
      _controllersSynced = true;
    }

    final occurredAt = state.occurredAt ?? DateTime.now();
    final direction = state.isCredit
        ? TransactionDirection.credit
        : TransactionDirection.debit;

    Category? selectedCategory;
    if (state.categoryId != null) {
      final matches = categories.where((c) => c.id == state.categoryId);
      selectedCategory = matches.isEmpty ? null : matches.first;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          state.isEditMode ? 'Modifica operazione' : 'Nuova operazione',
        ),
      ),
      body: state.isLoadingExisting
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: DirectionSegmentedControl(
                      isCredit: state.isCredit,
                      onChanged: controller.setDirection,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AmountField(
                    controller: _amountController,
                    errorText: fieldError('amount_minor'),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TitleAutocompleteField(
                    controller: _titleController,
                    direction: direction,
                    errorText: fieldError('title'),
                    onChanged: controller.setTitle,
                    onSuggestionSelected: (template) {
                      final matches = categories.where(
                        (c) => c.id == template.defaultCategoryId,
                      );
                      controller.applyTemplate(
                        template,
                        matches.isEmpty ? null : matches.first,
                      );
                      _descriptionController.text = ref
                          .read(
                            transactionFormControllerProvider(
                              widget.editTransactionId,
                            ),
                          )
                          .description;
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.label_outline),
                    title: Text(
                      selectedCategory?.name ??
                          AppLocalizations.of(context).noCategoryLabel,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _pickCategory(context, direction),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: state.mediaId == null
                        ? const Icon(Icons.image_outlined)
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppSpacing.inputRadius,
                            ),
                            child: Image(
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              image: NetworkImage(
                                ref
                                    .read(mediaRepositoryProvider)
                                    .contentUrl(state.mediaId!),
                                headers: ref
                                    .read(mediaRepositoryProvider)
                                    .authHeaders(),
                              ),
                            ),
                          ),
                    title: Text(
                      state.mediaId == null
                          ? 'Nessuna immagine'
                          : 'Immagine selezionata',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _pickImage(context),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Data e ora'),
                    subtitle: Text(
                      DateFormat('d MMMM y, HH:mm', 'it_IT').format(occurredAt),
                    ),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: () => _pickDateTime(context, occurredAt),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(
                        context,
                      ).descriptionOptionalLabel,
                    ),
                    onChanged: controller.setDescription,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      state.selectedTemplateId != null
                          ? 'Aggiorna anche il modello'
                          : 'Salva come modello',
                    ),
                    value: state.saveAsTemplate,
                    onChanged: controller.setSaveAsTemplate,
                  ),
                  if (state.error != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      presentError(state.error!, l10n).message,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    onPressed: state.isSubmitting ? null : _submit,
                    child: state.isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Salva operazione'),
                  ),
                ],
              ),
            ),
    );
  }
}
