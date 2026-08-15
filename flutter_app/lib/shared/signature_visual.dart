import 'dart:math';
import 'package:flutter/material.dart';
import '../app/theme.dart';

/// Animated node-graph visualization representing the state root.
/// Pulses in teal when a new batch commits (batchCount changes).
/// This is the one place the app is allowed to be loud.
class SignatureVisual extends StatefulWidget {
  final String stateRoot;
  final int batchCount;

  const SignatureVisual({
    super.key,
    required this.stateRoot,
    required this.batchCount,
  });

  @override
  State<SignatureVisual> createState() => _SignatureVisualState();
}

class _SignatureVisualState extends State<SignatureVisual>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;
  int _previousBatchCount = -1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.repeat(reverse: true);
    _previousBatchCount = widget.batchCount;
  }

  @override
  void didUpdateWidget(SignatureVisual oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.batchCount != _previousBatchCount) {
      _previousBatchCount = widget.batchCount;
      // New batch committed — trigger a strong pulse
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(double.infinity, 120),
          painter: _NodeGraphPainter(
            stateRoot: widget.stateRoot,
            pulseValue: _pulseAnimation.value,
          ),
        );
      },
    );
  }
}

class _NodeGraphPainter extends CustomPainter {
  final String stateRoot;
  final double pulseValue;

  _NodeGraphPainter({required this.stateRoot, required this.pulseValue});

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(stateRoot.hashCode);
    final nodeCount = 8 + (stateRoot.hashCode.abs() % 5);
    final nodes = <Offset>[];

    // Generate deterministic node positions from stateRoot hash.
    for (int i = 0; i < nodeCount; i++) {
      final x = 20 + random.nextDouble() * (size.width - 40);
      final y = 10 + random.nextDouble() * (size.height - 20);
      nodes.add(Offset(x, y));
    }

    final teal = AppColors.primaryAccent;
    final pulseOpacity = 0.3 + (pulseValue * 0.4);

    // Draw edges
    final edgePaint = Paint()
      ..color = teal.withValues(alpha: 0.12 + pulseValue * 0.08)
      ..strokeWidth = 1;

    for (int i = 0; i < nodes.length; i++) {
      for (int j = i + 1; j < nodes.length; j++) {
        final dist = (nodes[i] - nodes[j]).distance;
        if (dist < size.width * 0.45) {
          edgePaint.color = teal.withValues(
            alpha: (0.08 + pulseValue * 0.06) * (1 - dist / (size.width * 0.45)),
          );
          canvas.drawLine(nodes[i], nodes[j], edgePaint);
        }
      }
    }

    // Draw nodes
    for (int i = 0; i < nodes.length; i++) {
      final isCenter = i == 0;
      final radius = isCenter ? 5.0 + pulseValue * 2 : 3.0 + pulseValue;

      // Glow
      final glowPaint = Paint()
        ..color = teal.withValues(alpha: pulseOpacity * 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(nodes[i], radius + 4, glowPaint);

      // Core
      final nodePaint = Paint()..color = teal.withValues(alpha: pulseOpacity + 0.3);
      canvas.drawCircle(nodes[i], radius, nodePaint);
    }
  }

  @override
  bool shouldRepaint(_NodeGraphPainter oldDelegate) {
    return oldDelegate.pulseValue != pulseValue ||
        oldDelegate.stateRoot != stateRoot;
  }
}
