/// Spacing, radius, and sizing tokens from plan.md section 6.5. Base grid
/// is 4px; use these constants instead of ad-hoc numbers so spacing stays
/// consistent across features.
abstract final class AppSpacing {
  static const double grid = 4;

  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  static const double pagePaddingMobile = 16;
  static const double pagePaddingTablet = 24;

  static const double cardRadius = 18;
  static const double inputRadius = 14;

  static const double minTouchTarget = 48;
}
