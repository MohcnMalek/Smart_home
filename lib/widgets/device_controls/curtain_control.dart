import 'package:flutter/material.dart';
import '../../models/device.dart';

class CurtainControl extends StatelessWidget {
  final Device device;
  final ValueChanged<double> onSetLevel;

  const CurtainControl({
    super.key,
    required this.device,
    required this.onSetLevel,
  });

  @override
  Widget build(BuildContext context) {
    final v = (device.level ?? 50).clamp(0, 100).toDouble();

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
          const Text(
            'Curtain',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 10),
          Text('Ouverture: ${v.round()}%',
              style: const TextStyle(fontWeight: FontWeight.w900)),
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
