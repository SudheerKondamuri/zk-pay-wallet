import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app/theme.dart';
import '../core/constants.dart';

/// Primary and secondary CTA buttons with haptic feedback.
/// Teal = primary (actionable). Outlined = secondary.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isPrimary;
  final bool isDanger;
  final IconData? icon;
  final double? width;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.isPrimary = true,
    this.isDanger = false,
    this.icon,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isDanger
        ? AppColors.danger
        : isPrimary
            ? AppColors.primaryAccent
            : Colors.transparent;

    final foregroundColor = isPrimary || isDanger
        ? AppColors.background
        : AppColors.primaryAccent;

    final borderSide = isPrimary || isDanger
        ? BorderSide.none
        : const BorderSide(color: AppColors.primaryAccent, width: 1.5);

    return SizedBox(
      width: width,
      height: 48,
      child: TextButton(
        onPressed: isLoading
            ? null
            : () {
                HapticFeedback.lightImpact();
                onPressed?.call();
              },
        style: TextButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          disabledBackgroundColor: backgroundColor.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.buttonBorder,
            side: borderSide,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
          animationDuration: AppDuration.micro,
        ),
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foregroundColor,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: foregroundColor,
                        ),
                  ),
                ],
              ),
      ),
    );
  }
}
