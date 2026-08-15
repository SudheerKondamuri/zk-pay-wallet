import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../app/theme.dart';

/// Animated PIN indicator dots with:
/// - Scale-in animation when a dot fills
/// - Horizontal shake animation on error
class PinDots extends StatefulWidget {
  final int length;
  final int filledCount;
  final bool hasError;

  const PinDots({
    super.key,
    required this.length,
    required this.filledCount,
    this.hasError = false,
  });

  @override
  State<PinDots> createState() => _PinDotsState();
}

class _PinDotsState extends State<PinDots> with TickerProviderStateMixin {
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    // Produces a sinusoidal shake: 0 → 1 → -1 → 1 → -1 → 0
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
  }

  @override
  void didUpdateWidget(PinDots oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasError && !oldWidget.hasError) {
      _shakeController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        // Shake offset: sin wave for 3 oscillations
        final dx = _shakeAnimation.value *
            math.sin(_shakeController.value * math.pi * 6) *
            8;
        return Transform.translate(
          offset: Offset(dx, 0),
          child: child,
        );
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(widget.length, (i) {
          final filled = i < widget.filledCount;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _Dot(
              key: ValueKey('dot_$i'),
              filled: filled,
              hasError: widget.hasError,
            ),
          );
        }),
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final bool filled;
  final bool hasError;

  const _Dot({
    super.key,
    required this.filled,
    required this.hasError,
  });

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
    );
    if (widget.filled) _scaleController.value = 1.0;
  }

  @override
  void didUpdateWidget(_Dot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.filled && !oldWidget.filled) {
      _scaleController.forward(from: 0);
    } else if (!widget.filled && oldWidget.filled) {
      _scaleController.value = 0;
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.hasError ? AppColors.danger : AppColors.primaryAccent;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.filled ? _scaleAnimation.value : 1.0,
          child: AnimatedContainer(
            duration: AppDuration.micro,
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.filled ? color : Colors.transparent,
              border: Border.all(color: color, width: 1.5),
            ),
          ),
        );
      },
    );
  }
}
