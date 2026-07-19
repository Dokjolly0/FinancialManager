/// Period presets the backend understands (plan.md sections 7.12, 18.1).
enum ReportPreset {
  last30Days,
  last12Months,
  currentMonth,
  currentYear,
  allTime,
  custom;

  String toApi() => switch (this) {
    ReportPreset.last30Days => 'last_30_days',
    ReportPreset.last12Months => 'last_12_months',
    ReportPreset.currentMonth => 'current_month',
    ReportPreset.currentYear => 'current_year',
    ReportPreset.allTime => 'all_time',
    ReportPreset.custom => 'custom',
  };

  String get label => switch (this) {
    ReportPreset.last30Days => 'Ultimi 30 giorni',
    ReportPreset.last12Months => 'Ultimi 12 mesi',
    ReportPreset.currentMonth => 'Mese corrente',
    ReportPreset.currentYear => 'Anno corrente',
    ReportPreset.allTime => 'Intera cronologia',
    ReportPreset.custom => 'Personalizzato',
  };
}

/// The period the report screen is currently showing: a preset, plus the
/// explicit from/to dates only meaningful when [preset] is custom.
class ReportPeriodSelection {
  const ReportPeriodSelection({
    this.preset = ReportPreset.last30Days,
    this.customFrom,
    this.customTo,
  });

  final ReportPreset preset;
  final DateTime? customFrom;
  final DateTime? customTo;

  ReportPeriodSelection copyWith({
    ReportPreset? preset,
    DateTime? customFrom,
    DateTime? customTo,
  }) {
    return ReportPeriodSelection(
      preset: preset ?? this.preset,
      customFrom: customFrom ?? this.customFrom,
      customTo: customTo ?? this.customTo,
    );
  }
}
