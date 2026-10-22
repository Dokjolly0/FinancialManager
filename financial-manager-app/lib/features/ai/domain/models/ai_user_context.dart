/// Values accepted by the backend for [AiUserContext.incomeType].
const aiIncomeTypes = [
  'EMPLOYEE',
  'SELF_EMPLOYED',
  'STUDENT',
  'RETIRED',
  'UNEMPLOYED',
  'MIXED',
  'OTHER',
];

/// Values accepted for [AiUserContext.responseStyle].
const aiResponseStyles = ['CONCISE', 'DETAILED'];

/// Matches the backend MaxContextTextLength.
const aiContextTextMaxLength = 2000;

/// What the user wants the model to know about them (plan.md section
/// 32.3). Every field is optional.
class AiUserContext {
  const AiUserContext({
    this.householdSize,
    this.incomeType,
    this.aboutMe,
    this.goals,
    this.ignoreNotes,
    this.responseStyle,
    this.version = 0,
    this.updatedAt,
  });

  final int? householdSize;
  final String? incomeType;
  final String? aboutMe;
  final String? goals;
  final String? ignoreNotes;
  final String? responseStyle;
  final int version;
  final DateTime? updatedAt;

  bool get isEmpty =>
      householdSize == null &&
      incomeType == null &&
      aboutMe == null &&
      goals == null &&
      ignoreNotes == null &&
      responseStyle == null;

  static AiUserContext fromJson(Map<String, dynamic> json) => AiUserContext(
    householdSize: json['household_size'] as int?,
    incomeType: json['income_type'] as String?,
    aboutMe: json['about_me'] as String?,
    goals: json['goals'] as String?,
    ignoreNotes: json['ignore_notes'] as String?,
    responseStyle: json['response_style'] as String?,
    version: json['version'] as int? ?? 0,
    updatedAt: json['updated_at'] is String
        ? DateTime.parse(json['updated_at'] as String)
        : null,
  );

  Map<String, dynamic> toJson() => {
    'household_size': householdSize,
    'income_type': incomeType,
    'about_me': aboutMe,
    'goals': goals,
    'ignore_notes': ignoreNotes,
    'response_style': responseStyle,
    'version': version,
  };
}
