import 'dart:math' as math;
import 'package:flutter/material.dart';

class StylishBackground extends StatelessWidget {
  const StylishBackground({
    super.key,
    required this.intensity,
    this.hueShift = 0.0,
  });

  /// 0..1
  final double intensity;
  final double hueShift;

  @override
  Widget build(BuildContext context) {
    final v = intensity.clamp(0.0, 1.0);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: v),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (_, t, __) {
        return CustomPaint(
          painter: _BackgroundPainter(
            intensity: t,
            hueShift: hueShift,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _BackgroundPainter extends CustomPainter {
  _BackgroundPainter({required this.intensity, required this.hueShift});

  final double intensity; // 0..1
  final double hueShift;

  @override
  void paint(Canvas canvas, Size size) {
    // Fond
    final bg = Paint()..color = const Color(0xFFF6F7FB);
    canvas.drawRect(Offset.zero & size, bg);

    // Bulles / glow (plus intensity => plus visible)
    final center1 = Offset(size.width * 0.2, size.height * 0.15);
    final center2 = Offset(size.width * 0.9, size.height * 0.25);
    final center3 = Offset(size.width * 0.65, size.height * 0.95);

    _drawGlow(canvas, size, center1, size.width * 0.55, intensity * 0.55);
    _drawGlow(canvas, size, center2, size.width * 0.50, intensity * 0.45);
    _drawGlow(canvas, size, center3, size.width * 0.65, intensity * 0.60);

    // Légère texture
    _drawSoftNoise(canvas, size, intensity * 0.10);
  }

  void _drawGlow(Canvas canvas, Size size, Offset c, double r, double alpha) {
    final a = (alpha.clamp(0.0, 1.0) * 0.18).clamp(0.0, 0.18);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withOpacity(a),
          Colors.white.withOpacity(0.0),
        ],
      ).createShader(Rect.fromCircle(center: c, radius: r));

    canvas.drawCircle(c, r, paint);
  }

  void _drawSoftNoise(Canvas canvas, Size size, double alpha) {
    if (alpha <= 0) return;
    final rnd = math.Random(1); // stable
    final p = Paint()..color = Colors.black.withOpacity(alpha.clamp(0.0, 0.05));

    // points très légers
    for (int i = 0; i < 140; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      canvas.drawCircle(Offset(x, y), rnd.nextDouble() * 1.1, p);
    }
  }

  @override
  bool shouldRepaint(covariant _BackgroundPainter oldDelegate) {
    // ✅ IMPORTANT: sinon l’intensité reste figée
    return oldDelegate.intensity != intensity || oldDelegate.hueShift != hueShift;
  }
}
