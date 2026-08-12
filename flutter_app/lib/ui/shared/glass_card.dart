import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';

/// Reserved glassmorphism card — Dashboard balance, Review sheet,
/// and signature visualization only. Everything else uses FlatCard.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.cardBorder,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: padding ??
              const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.glassFill,
            borderRadius: AppRadius.cardBorder,
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: child,
        ),
      ),
    );
  }
}
