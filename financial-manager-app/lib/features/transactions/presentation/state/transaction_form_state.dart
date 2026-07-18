class TransactionFormState {
  const TransactionFormState({
    this.isLoadingExisting = false,
    this.isCredit = false,
    this.amountInput = '',
    this.title = '',
    this.description = '',
    this.occurredAt,
    this.expectedVersion,
    this.isSubmitting = false,
    this.generalError,
    this.fieldErrors = const {},
  });

  final bool isLoadingExisting;
  final bool isCredit;
  final String amountInput;
  final String title;
  final String description;
  final DateTime? occurredAt;
  final int? expectedVersion;
  final bool isSubmitting;
  final String? generalError;
  final Map<String, String> fieldErrors;

  bool get isEditMode => expectedVersion != null;

  TransactionFormState copyWith({
    bool? isLoadingExisting,
    bool? isCredit,
    String? amountInput,
    String? title,
    String? description,
    DateTime? occurredAt,
    int? expectedVersion,
    bool? isSubmitting,
    String? generalError,
    Map<String, String>? fieldErrors,
  }) {
    return TransactionFormState(
      isLoadingExisting: isLoadingExisting ?? this.isLoadingExisting,
      isCredit: isCredit ?? this.isCredit,
      amountInput: amountInput ?? this.amountInput,
      title: title ?? this.title,
      description: description ?? this.description,
      occurredAt: occurredAt ?? this.occurredAt,
      expectedVersion: expectedVersion ?? this.expectedVersion,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      generalError: generalError,
      fieldErrors: fieldErrors ?? this.fieldErrors,
    );
  }
}
