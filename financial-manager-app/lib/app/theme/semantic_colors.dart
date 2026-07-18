import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Financial-meaning colors that Material's [ColorScheme] has no slot for:
/// credit/debit direction, warning, and informational tones (plan.md
/// section 6.3). Access via `Theme.of(context).extension<SemanticColors>()`.
///
/// These colors must never be the only way a user distinguishes credit from
/// debit (plan.md section 6.7) — always pair with icon, sign, and label.
@immutable
class SemanticColors extends ThemeExtension<SemanticColors> {
  const SemanticColors({
    required this.credit,
    required this.debit,
    required this.warning,
    required this.info,
  });

  final Color credit;
  final Color debit;
  final Color warning;
  final Color info;

  static const light = SemanticColors(
    credit: AppColors.creditLight,
    debit: AppColors.debitLight,
    warning: AppColors.warningLight,
    info: AppColors.infoLight,
  );

  static const dark = SemanticColors(
    credit: AppColors.creditDark,
    debit: AppColors.debitDark,
    warning: AppColors.warningDark,
    info: AppColors.infoDark,
  );

  @override
  SemanticColors copyWith({
    Color? credit,
    Color? debit,
    Color? warning,
    Color? info,
  }) {
    return SemanticColors(
      credit: credit ?? this.credit,
      debit: debit ?? this.debit,
      warning: warning ?? this.warning,
      info: info ?? this.info,
    );
  }

  @override
  SemanticColors lerp(ThemeExtension<SemanticColors>? other, double t) {
    if (other is! SemanticColors) return this;
    return SemanticColors(
      credit: Color.lerp(credit, other.credit, t)!,
      debit: Color.lerp(debit, other.debit, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
    );
  }
}

extension SemanticColorsContext on BuildContext {
  /// Shorthand for `Theme.of(this).extension<SemanticColors>()!`.
  SemanticColors get semanticColors =>
      Theme.of(this).extension<SemanticColors>()!;
}
