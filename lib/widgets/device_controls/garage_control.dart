import 'package:flutter/material.dart';
import '../../models/device.dart';

class GarageControl extends StatelessWidget {
  final Device device;
  const GarageControl({super.key, required this.device});

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
          const Text(
            'Garage Door',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            device.isOn ? 'OPEN' : 'CLOSED',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          const Text(
            'Astuce: utilisez le switch en haut pour ouvrir/fermer.',
            style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
