import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';

/// Tinted shimmer loading state — matches flat surface color.
/// Never a bare spinner as primary loading state.
class SkeletonLoader extends StatelessWidget {
  final int lineCount;
  final bool showCircle;

  const SkeletonLoader({
    super.key,
    this.lineCount = 3,
    this.showCircle = false,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceFlat,
      highlightColor: AppColors.surfaceFlat.withValues(alpha: 0.6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showCircle) ...[
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: AppSpacing.base),
          ],
          for (int i = 0; i < lineCount; i++) ...[
            Container(
              height: 14,
              width: i == lineCount - 1 ? 120 : double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            if (i < lineCount - 1) const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}

/// Balance card skeleton — matches the Dashboard glass card layout.
class BalanceSkeleton extends StatelessWidget {
  const BalanceSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceFlat,
      highlightColor: AppColors.surfaceFlat.withValues(alpha: 0.6),
      child: Column(
        children: [
          Container(
            height: 16,
            width: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            height: 40,
            width: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}
