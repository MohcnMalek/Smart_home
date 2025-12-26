import 'package:flutter/material.dart';
import '../../models/device.dart';

class ACControl extends StatefulWidget {
  final Device device;
  final void Function(double temp, String mode) onSet;

  const ACControl({
    super.key,
    required this.device,
    required this.onSet,
  });

  @override
  State<ACControl> createState() => _ACControlState();
}

class _ACControlState extends State<ACControl> {
  late double _temp;
  late String _mode;

  @override
  void initState() {
    super.initState();
    _temp = (widget.device.temp ?? 24).clamp(16, 30).toDouble();
    _mode = (widget.device.mode ?? 'auto').toString();
  }

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
            'Air Conditioner',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 10),
          Text('${_temp.round()}°C',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          Slider(
            value: _temp,
            min: 16,
            max: 30,
            divisions: 14,
            label: '${_temp.round()}',
            onChanged: (v) {
              setState(() => _temp = v);
              widget.onSet(_temp, _mode);
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('Mode: ', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(width: 10),
              DropdownButton<String>(
                value: _mode,
                items: const [
                  DropdownMenuItem(value: 'auto', child: Text('Auto')),
                  DropdownMenuItem(value: 'cool', child: Text('Cool')),
                  DropdownMenuItem(value: 'heat', child: Text('Heat')),
                ],
                onChanged: (m) {
                  if (m == null) return;
                  setState(() => _mode = m);
                  widget.onSet(_temp, _mode);
                },
              )
            ],
          )
        ],
      ),
    );
  }
}
