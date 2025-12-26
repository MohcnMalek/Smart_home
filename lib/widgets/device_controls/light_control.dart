import 'package:flutter/material.dart';
import '../../models/device.dart';

class LightControl extends StatelessWidget {
  final Device device;
  final ValueChanged<double> onSetLevel;

  const LightControl({
    super.key,
    required this.device,
    required this.onSetLevel,
  });

  @override
  Widget build(BuildContext context) {
    final v = (device.level ?? 70).clamp(0, 100).toDouble();

    return _Card(
      title: 'Brightness',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${v.round()}%', style: const TextStyle(fontWeight: FontWeight.w900)),
          Slider(
            value: v,
            min: 0,
            max: 100,
            onChanged: (x) => onSetLevel(x),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;

  const _Card({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF6B7280),
              )),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
