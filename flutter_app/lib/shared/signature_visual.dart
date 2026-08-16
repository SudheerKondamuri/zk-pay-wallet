import 'dart:math';
import 'package:flutter/material.dart';
import '../app/theme.dart';

/// Animated node-graph visualization representing the cryptographic state root.
/// Continuously breathes with orbital drift, edge connections, and pulse animations.
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
  int _previousBatchCount = -1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
    _previousBatchCount = widget.batchCount;
  }

  @override
  void didUpdateWidget(SignatureVisual oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.batchCount != _previousBatchCount) {
      _previousBatchCount = widget.batchCount;
      // Re-trigger continuous loop seamlessly
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
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
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(double.infinity, 120),
          painter: _NodeGraphPainter(
            stateRoot: widget.stateRoot,
            progress: _controller.value,
          ),
        );
      },
    );
  }
}

class _NodeGraphPainter extends CustomPainter {
  final String stateRoot;
  final double progress;

  _NodeGraphPainter({required this.stateRoot, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(stateRoot.hashCode);
    final nodeCount = 8 + (stateRoot.hashCode.abs() % 5);
    final nodes = <Offset>[];

    // Compute pulse value using smooth sine curve
    final pulseValue = (sin(progress * 2 * pi) + 1.0) / 2.0;

    // Generate deterministic base positions + smooth orbital floating drift
    for (int i = 0; i < nodeCount; i++) {
      final baseX = 24 + random.nextDouble() * (size.width - 48);
      final baseY = 16 + random.nextDouble() * (size.height - 32);
      
      final orbitalSpeed = 1.0 + (i % 3) * 0.5;
      final phase = (i * 1.3) + (progress * 2 * pi * orbitalSpeed);
      final driftX = sin(phase) * (3.0 + (i % 4));
      final driftY = cos(phase) * (2.5 + (i % 3));

      nodes.add(Offset(baseX + driftX, baseY + driftY));
    }

    final teal = AppColors.primaryAccent;
    final pulseOpacity = 0.35 + (pulseValue * 0.45);

    // Draw dynamic connections between neighboring nodes
    final edgePaint = Paint()
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < nodes.length; i++) {
      for (int j = i + 1; j < nodes.length; j++) {
        final dist = (nodes[i] - nodes[j]).distance;
        final maxDist = size.width * 0.42;
        if (dist < maxDist) {
          final proximity = 1.0 - (dist / maxDist);
          final edgeAlpha = (0.06 + pulseValue * 0.12) * proximity;
          edgePaint.color = teal.withValues(alpha: edgeAlpha.clamp(0.0, 1.0));
          canvas.drawLine(nodes[i], nodes[j], edgePaint);
        }
      }
    }

    // Draw scanning telemetry sweep line
    final scanX = (progress * (size.width + 40)) - 20;
    final scanPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          teal.withValues(alpha: 0.0),
          teal.withValues(alpha: 0.12),
          teal.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(scanX - 30, 0, 60, size.height));
    canvas.drawRect(Rect.fromLTWH(scanX - 30, 0, 60, size.height), scanPaint);

    // Draw glowing nodes with halo and core
    for (int i = 0; i < nodes.length; i++) {
      final isHub = i == 0 || i == nodes.length ~/ 2;
      final nodePhase = (progress * 2 * pi) + (i * 0.8);
      final localPulse = (sin(nodePhase) + 1.0) / 2.0;

      final radius = isHub ? 4.5 + localPulse * 2.0 : 2.5 + localPulse * 1.5;

      // Outer blur glow
      final glowPaint = Paint()
        ..color = teal.withValues(alpha: (pulseOpacity * 0.35).clamp(0.0, 1.0))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(nodes[i], radius + 4, glowPaint);

      // Core particle
      final nodePaint = Paint()
        ..color = isHub
            ? AppColors.primaryAccent
            : teal.withValues(alpha: (0.5 + localPulse * 0.5).clamp(0.0, 1.0));
      canvas.drawCircle(nodes[i], radius, nodePaint);
    }
  }

  @override
  bool shouldRepaint(_NodeGraphPainter oldDelegate) {
    return true;
  }
}
