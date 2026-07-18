import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/amount_field.dart';
import '../../../../core/widgets/direction_segmented_control.dart';
import '../view_models/transaction_form_controller.dart';

/// New / edit operation (plan.md section 7.6, 7.11 — the same form).
/// Category and title-autocomplete-from-templates are deferred to Fase 5
/// (categories, transaction templates); image attachment to Fase 6 (media).
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

    if (!_controllersSynced && !state.isLoadingExisting) {
      _amountController.text = state.amountInput;
      _titleController.text = state.title;
      _descriptionController.text = state.description;
      _controllersSynced = true;
    }

    final occurredAt = state.occurredAt ?? DateTime.now();

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
                    errorText: state.fieldErrors['amount_minor'],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Titolo',
                      errorText: state.fieldErrors['title'],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
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
                    decoration: const InputDecoration(
                      labelText: 'Descrizione (facoltativa)',
                    ),
                  ),
                  if (state.generalError != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      state.generalError!,
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
