import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../core/constants.dart';

/// Standard flat surface card — #1A211C on #0F1512.
/// Used everywhere except the three glass-reserved surfaces.
class FlatCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  const FlatCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding ?? const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.surfaceFlat,
        borderRadius: AppRadius.cardBorder,
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.cardBorder,
          splashColor: AppColors.primaryAccent.withValues(alpha: 0.08),
          child: card,
        ),
      );
    }

    return card;
  }
}
