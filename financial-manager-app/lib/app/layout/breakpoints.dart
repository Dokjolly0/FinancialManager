import 'package:flutter/material.dart';

/// Window size classes for the web dashboard and tablets (Material 3):
/// compact keeps the phone layout, medium and expanded get a side rail.
abstract final class Breakpoints {
  static const double medium = 840;
  static const double expanded = 1200;

  /// Widest a page pushed over the tabs (forms, details, settings) grows.
  static const double pageMaxWidth = 840;

  /// Widest the tab content (home, history, reports, account) grows.
  static const double shellMaxWidth = 1100;

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= medium;

  static bool isExpanded(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= expanded;
}

/// Centers [child] at most [maxWidth] wide on a tinted background when the
/// window is wider than that; on a phone it is just [child].
class AdaptivePage extends StatelessWidget {
  const AdaptivePage({
    super.key,
    required this.child,
    this.maxWidth = Breakpoints.pageMaxWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width <= maxWidth) return child;
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Material(elevation: 1, child: child),
        ),
      ),
    );
  }
}
