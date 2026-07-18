import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';

/// Loading placeholder for list screens (plan.md section 6.6 / 7.15):
/// shows a handful of shimmer-less skeleton rows so the layout doesn't
/// jump once real content arrives. Deliberately simple (no shimmer
/// animation library) — can be upgraded later without changing the API.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.itemCount = 6, this.itemHeight = 64});

  final int itemCount;
  final double itemHeight;

  @override
  Widget build(BuildContext context) {
    final baseColor = Theme.of(context).colorScheme.surfaceContainerHighest;

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: itemCount,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, index) {
        return Container(
          height: itemHeight,
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          ),
        );
      },
    );
  }
}
