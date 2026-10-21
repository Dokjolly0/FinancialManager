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

/// The compact profile's transaction list (plan.md section 33).
const aiCompactDefaultTransactions = 60;
const aiCompactMaxTransactions = 100;

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

/// Restricts an analysis to part of the ledger, with the same meaning as
/// the Cronologia filters (plan.md section 32.6).
class AiAnalysisFilters {
  const AiAnalysisFilters({
    this.direction,
    this.categoryId,
    this.title,
    this.amountMinMinor,
    this.amountMaxMinor,
  });

  /// 'DEBIT', 'CREDIT' or null for both.
  final String? direction;
  final String? categoryId;
  final String? title;
  final int? amountMinMinor;
  final int? amountMaxMinor;

  bool get isEmpty =>
      direction == null &&
      categoryId == null &&
      (title == null || title!.trim().isEmpty) &&
      amountMinMinor == null &&
      amountMaxMinor == null;

  /// A copy with the given fields removed.
  AiAnalysisFilters without({
    bool direction = false,
    bool categoryId = false,
    bool title = false,
    bool amountMin = false,
    bool amountMax = false,
  }) => AiAnalysisFilters(
    direction: direction ? null : this.direction,
    categoryId: categoryId ? null : this.categoryId,
    title: title ? null : this.title,
    amountMinMinor: amountMin ? null : amountMinMinor,
    amountMaxMinor: amountMax ? null : amountMaxMinor,
  );

  Map<String, dynamic> toJson() => {
    'direction': ?direction,
    'category_id': ?categoryId,
    if (title != null && title!.trim().isNotEmpty) 'title': title!.trim(),
    'amount_min_minor': ?amountMinMinor,
    'amount_max_minor': ?amountMaxMinor,
  };
}

/// The phone model's limits, for an on-device preview's context fit.
class AiDeviceParams {
  const AiDeviceParams({
    required this.contextTokens,
    required this.maxOutputTokens,
  });

  final int contextTokens;
  final int maxOutputTokens;

  Map<String, dynamic> toJson() => {
    'context_tokens': contextTokens,
    'max_output_tokens': maxOutputTokens,
  };
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
    this.filters,
    this.instructions,
    this.profile,
    this.budgetTokens,
    this.target,
    this.device,
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

  /// Null or empty: no restriction beyond period and wallets.
  final AiAnalysisFilters? filters;

  /// Null uses the preset's default instructions.
  final String? instructions;

  /// 'standard' or 'compact' (small on-device models); null is standard.
  final String? profile;

  /// When set, the server drops detail until the prompt fits.
  final int? budgetTokens;

  /// 'cloud' or 'on_device'; null uses the saved mode.
  final String? target;
  final AiDeviceParams? device;

  AiAnalysisRequest copyWith({
    String? instructions,
    bool? includeTransactions,
    int? maxTransactions,
    String? profile,
    int? budgetTokens,
    AiDeviceParams? device,
  }) => AiAnalysisRequest(
    preset: preset,
    periodPreset: periodPreset,
    customFrom: customFrom,
    customTo: customTo,
    walletIds: walletIds,
    sections: sections,
    includeTransactions: includeTransactions ?? this.includeTransactions,
    maxTransactions: maxTransactions ?? this.maxTransactions,
    anonymizeTitles: anonymizeTitles,
    includeAdjustments: includeAdjustments,
    filters: filters,
    instructions: instructions ?? this.instructions,
    profile: profile ?? this.profile,
    budgetTokens: budgetTokens ?? this.budgetTokens,
    target: target,
    device: device ?? this.device,
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
      if (filters != null && !filters!.isEmpty) 'filters': filters!.toJson(),
      'profile': ?profile,
      'budget_tokens': ?budgetTokens,
    },
    'target': ?target,
    if (device != null) 'device': device!.toJson(),
    'instructions': instructions,
  };
}
