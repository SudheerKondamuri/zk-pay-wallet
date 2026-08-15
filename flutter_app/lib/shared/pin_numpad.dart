import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants.dart';
import '../app/theme.dart';

/// Premium glass-circle numpad for PIN entry screens.
///
/// [onDigit] fires with '0'–'9'.
/// [onDelete] fires when the backspace key is tapped.
/// [onBiometric] when non-null, shows a fingerprint button at bottom-left.
class PinNumpad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final VoidCallback? onBiometric;

  const PinNumpad({
    super.key,
    required this.onDigit,
    required this.onDelete,
    this.onBiometric,
  });

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['bio', '0', 'del'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: _rows.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row.map((key) => _buildKey(context, key)).toList(),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildKey(BuildContext context, String key) {
    const size = 76.0;

    if (key == 'bio') {
      if (onBiometric == null) {
        return const SizedBox(width: size, height: size);
      }
      return _GlassCircleButton(
        size: size,
        onTap: () {
          HapticFeedback.selectionClick();
          onBiometric!();
        },
        child: const Icon(
          Icons.fingerprint,
          color: AppColors.textSecondary,
          size: 28,
        ),
      );
    }

    if (key == 'del') {
      return _GlassCircleButton(
        size: size,
        onTap: () {
          HapticFeedback.selectionClick();
          onDelete();
        },
        child: const Icon(
          Icons.backspace_outlined,
          color: AppColors.textSecondary,
          size: 24,
        ),
      );
    }

    // Digit
    return _GlassCircleButton(
      size: size,
      onTap: () {
        HapticFeedback.selectionClick();
        onDigit(key);
      },
      child: Text(
        key,
        style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w400,
              color: AppColors.textPrimary,
            ),
      ),
    );
  }
}

/// A circular button with a subtle glass background and border.
/// Tapping produces an ink ripple constrained inside the circle.
class _GlassCircleButton extends StatelessWidget {
  final double size;
  final VoidCallback onTap;
  final Widget child;

  const _GlassCircleButton({
    required this.size,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: AppColors.glassFill,
        shape: CircleBorder(
          side: BorderSide(
            color: AppColors.glassBorder,
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          splashColor: AppColors.primaryAccent.withValues(alpha: 0.12),
          highlightColor: AppColors.primaryAccent.withValues(alpha: 0.06),
          child: Center(child: child),
        ),
      ),
    );
  }
}
