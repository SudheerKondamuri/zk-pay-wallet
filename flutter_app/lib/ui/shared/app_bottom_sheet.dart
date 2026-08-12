import 'package:flutter/material.dart';
import '../../core/constants.dart';

/// Standard bottom sheet wrapper with 24px top radius.
/// Handles safe area and max height.
class AppBottomSheet extends StatelessWidget {
  final Widget child;
  final double maxHeightFraction;

  const AppBottomSheet({
    super.key,
    required this.child,
    this.maxHeightFraction = 0.9,
  });

  /// Show this bottom sheet as a modal.
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    double maxHeightFraction = 0.9,
    bool isDismissible = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      backgroundColor: Colors.transparent,
      transitionAnimationController: AnimationController(
        vsync: Navigator.of(context),
        duration: AppDuration.sheet,
      ),
      builder: (context) => AppBottomSheet(
        maxHeightFraction: maxHeightFraction,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * maxHeightFraction,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A211C),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: AppSpacing.sm),
              // Drag handle
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppSpacing.base),
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );
  }
}
