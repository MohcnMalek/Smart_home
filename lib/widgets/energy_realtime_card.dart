import 'dart:math' as math;
import 'package:flutter/material.dart';

class EnergyRealtimeCard extends StatelessWidget {
  const EnergyRealtimeCard({
    super.key,
    required this.values,
    this.title = 'REAL-TIME USAGE',
    this.height = 130,
  });

  final List<double> values; // ex: vm.energyHistory
  final String title;
  final double height;

  @override
  Widget build(BuildContext context) {
    final safe = values.isEmpty ? const <double>[0] : values;
    final maxV = safe.reduce(math.max);
    final minV = safe.reduce(math.min);
    final range = (maxV - minV).abs() < 1e-9 ? 1.0 : (maxV - minV);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.75)),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: height,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(10),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutCubic,
                builder: (context, t, _) {
                  return CustomPaint(
                    painter: _EnergyLinePainter(
                      values: safe,
                      minV: minV,
                      range: range,
                      progress: t,
                    ),
                    child: const SizedBox.expand(),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Based on devices ON/OFF',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white.withOpacity(0.55),
            ),
          ),
        ],
      ),
    );
  }
}

class _EnergyLinePainter extends CustomPainter {
  _EnergyLinePainter({
    required this.values,
    required this.minV,
    required this.range,
    required this.progress,
  });

  final List<double> values;
  final double minV;
  final double range;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    // grid
    final grid = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 1;

    for (int i = 1; i <= 3; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    if (values.length < 2) return;

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFF97316);

    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFF97316).withOpacity(0.14);

    // points
    final n = values.length;
    final dx = size.width / (n - 1);

    Offset p(int i) {
      final norm = ((values[i] - minV) / range).clamp(0.0, 1.0);
      final x = dx * i;
      final y = size.height - (norm * size.height);
      return Offset(x, y);
    }

    // path
    final path = Path()..moveTo(p(0).dx, p(0).dy);
    for (int i = 1; i < n; i++) {
      final pt = p(i);
      path.lineTo(pt.dx, pt.dy);
    }

    // animate by extracting path length
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final totalLen = metrics.fold<double>(0, (a, m) => a + m.length);
    final drawLen = totalLen * progress;

    final animated = Path();
    double used = 0;
    for (final m in metrics) {
      final remain = drawLen - used;
      if (remain <= 0) break;
      final len = math.min(m.length, remain);
      animated.addPath(m.extractPath(0, len), Offset.zero);
      used += len;
    }

    // fill under line
    final fill = Path.from(animated)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(fill, fillPaint);
    canvas.drawPath(animated, linePaint);
  }

  @override
  bool shouldRepaint(covariant _EnergyLinePainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.minV != minV ||
        oldDelegate.range != range ||
        oldDelegate.progress != progress;
  }
}
