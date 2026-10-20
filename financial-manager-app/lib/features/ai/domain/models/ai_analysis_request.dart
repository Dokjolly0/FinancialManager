/// Optional data sections (plan.md section 32.6). Period, wallets and
/// totals are always sent.
enum AiDataSection {
  monthly('monthly'),
  categories('categories'),
  titles('titles'),
  transfers('transfers'),
  recurring('recurring'),
  personalContext('personal_context');

  const AiDataSection(this.wire);

  final String wire;

  static AiDataSection? fromWire(String value) {
    for (final s in AiDataSection.values) {
      if (s.wire == value) return s;
    }
    return null;
  }
}

/// Matches the backend limits.
const aiMaxTransactions = 500;
const aiDefaultMaxTransactions = 200;
const aiInstructionsMaxLength = 4000;

/// A preset offered on the setup screen, localized by the backend.
class AiPreset {
  const AiPreset({
    required this.id,
    required this.title,
    required this.description,
    required this.defaultInstructions,
    required this.defaultSections,
    required this.defaultIncludeTransactions,
    required this.defaultPeriodPreset,
  });

  final String id;
  final String title;
  final String description;
  final String defaultInstructions;
  final Set<AiDataSection> defaultSections;
  final bool defaultIncludeTransactions;
  final String defaultPeriodPreset;

  bool get isCustom => id == 'CUSTOM';

  static AiPreset fromJson(Map<String, dynamic> json) => AiPreset(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String? ?? '',
    defaultInstructions: json['default_instructions'] as String? ?? '',
    defaultSections: (json['default_sections'] as List<dynamic>? ?? const [])
        .map((s) => AiDataSection.fromWire(s as String))
        .whereType<AiDataSection>()
        .toSet(),
    defaultIncludeTransactions:
        json['default_include_transactions'] as bool? ?? false,
    defaultPeriodPreset:
        json['default_period_preset'] as String? ?? 'last_12_months',
  );
}

/// The body shared by preview and run.
class AiAnalysisRequest {
  const AiAnalysisRequest({
    required this.preset,
    this.periodPreset = 'last_12_months',
    this.customFrom,
    this.customTo,
    this.walletIds = const [],
    this.sections = const {},
    this.includeTransactions = false,
    this.maxTransactions = aiDefaultMaxTransactions,
    this.anonymizeTitles = false,
    this.includeAdjustments = false,
    this.instructions,
  });

  final String preset;
  final String periodPreset;
  final DateTime? customFrom;
  final DateTime? customTo;

  /// Empty means every wallet.
  final List<String> walletIds;
  final Set<AiDataSection> sections;
  final bool includeTransactions;
  final int maxTransactions;
  final bool anonymizeTitles;
  final bool includeAdjustments;

  /// Null uses the preset's default instructions.
  final String? instructions;

  AiAnalysisRequest copyWith({String? instructions}) => AiAnalysisRequest(
    preset: preset,
    periodPreset: periodPreset,
    customFrom: customFrom,
    customTo: customTo,
    walletIds: walletIds,
    sections: sections,
    includeTransactions: includeTransactions,
    maxTransactions: maxTransactions,
    anonymizeTitles: anonymizeTitles,
    includeAdjustments: includeAdjustments,
    instructions: instructions ?? this.instructions,
  );

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
    'preset': preset,
    'period': {
      'preset': periodPreset,
      if (periodPreset == 'custom' && customFrom != null)
        'from': _date(customFrom!),
      if (periodPreset == 'custom' && customTo != null) 'to': _date(customTo!),
    },
    'wallet_ids': walletIds,
    'options': {
      'sections': [
        for (final s in AiDataSection.values)
          if (sections.contains(s)) s.wire,
      ],
      'include_transactions': includeTransactions,
      'max_transactions': maxTransactions,
      'anonymize_titles': anonymizeTitles,
      'include_adjustments': includeAdjustments,
    },
    'instructions': instructions,
  };
}
