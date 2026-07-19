import '../../../../core/errors/app_error.dart';

class TransactionFormState {
  const TransactionFormState({
    this.isLoadingExisting = false,
    this.isCredit = false,
    this.amountInput = '',
    this.title = '',
    this.description = '',
    this.categoryId,
    this.selectedTemplateId,
    this.saveAsTemplate = false,
    this.mediaId,
    this.occurredAt,
    this.expectedVersion,
    this.isSubmitting = false,
    this.error,
    this.fieldErrors = const {},
  });

  final bool isLoadingExisting;
  final bool isCredit;
  final String amountInput;
  final String title;
  final String description;
  final String? categoryId;
  final String? selectedTemplateId;
  final bool saveAsTemplate;
  final String? mediaId;
  final DateTime? occurredAt;
  final int? expectedVersion;
  final bool isSubmitting;
  final AppError? error;
  final Map<String, String> fieldErrors;

  bool get isEditMode => expectedVersion != null;

  TransactionFormState copyWith({
    bool? isLoadingExisting,
    bool? isCredit,
    String? amountInput,
    String? title,
    String? description,
    String? categoryId,
    bool clearCategory = false,
    String? selectedTemplateId,
    bool clearSelectedTemplate = false,
    bool? saveAsTemplate,
    String? mediaId,
    bool clearMedia = false,
    DateTime? occurredAt,
    int? expectedVersion,
    bool? isSubmitting,
    AppError? error,
    Map<String, String>? fieldErrors,
  }) {
    return TransactionFormState(
      isLoadingExisting: isLoadingExisting ?? this.isLoadingExisting,
      isCredit: isCredit ?? this.isCredit,
      amountInput: amountInput ?? this.amountInput,
      title: title ?? this.title,
      description: description ?? this.description,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      selectedTemplateId: clearSelectedTemplate
          ? null
          : (selectedTemplateId ?? this.selectedTemplateId),
      saveAsTemplate: saveAsTemplate ?? this.saveAsTemplate,
      mediaId: clearMedia ? null : (mediaId ?? this.mediaId),
      occurredAt: occurredAt ?? this.occurredAt,
      expectedVersion: expectedVersion ?? this.expectedVersion,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error,
      fieldErrors: fieldErrors ?? this.fieldErrors,
    );
  }
}
