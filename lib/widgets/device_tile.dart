//device_tile.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/device.dart';
import '../providers/home_provider.dart';
import '../views/device_control_page.dart';

class DeviceTile extends StatelessWidget {
  const DeviceTile({
    super.key,
    required this.roomId,
    required this.device,
  });

  final String roomId;
  final Device device;

  bool get _hasImage => device.imagePath.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final isOn = device.isOn;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DeviceControlPage(
              roomId: roomId,
              deviceId: device.id,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isOn ? const Color(0xFF111827) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _IconBox(
                  dark: isOn,
                  child: _hasImage
                      ? Image.asset(
                          device.imagePath,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Icon(
                            device.icon,
                            color: isOn ? Colors.white : const Color(0xFF111111),
                          ),
                        )
                      : Icon(
                          device.icon,
                          color: isOn ? Colors.white : const Color(0xFF111111),
                        ),
                ),
                const Spacer(),
                Transform.scale(
                  scale: 0.92,
                  child: Switch(
                    value: isOn,
                    onChanged: (_) => context.read<HomeProvider>().toggleDevice(device.id),
                    activeColor: Colors.white,
                    activeTrackColor: Colors.white.withOpacity(0.35),
                    inactiveThumbColor: const Color(0xFF111827),
                    inactiveTrackColor: const Color(0xFF111827).withOpacity(0.15),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              device.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: isOn ? Colors.white : const Color(0xFF111111),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _labelType(device.type),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isOn ? Colors.white.withOpacity(0.75) : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.bottomLeft,
              child: _StatusPill(isOn: isOn),
            ),
          ],
        ),
      ),
    );
  }

  String _labelType(String t) {
    switch (t) {
      case 'light':
        return 'Lumière';
      case 'tv':
        return 'Télévision';
      case 'ac':
        return 'Climatiseur';
      case 'curtain':
        return 'Rideaux';
      case 'socket':
        return 'Prise';
      case 'camera':
        return 'Caméra';
      case 'garage_door':
        return 'Porte garage';
      default:
        return t;
    }
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.child, required this.dark});

  final Widget child;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: dark ? Colors.white.withOpacity(0.10) : const Color(0xFFF2F3F7),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(10),
      child: Center(child: child),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.isOn});
  final bool isOn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isOn ? Colors.white.withOpacity(0.12) : const Color(0xFFF2F3F7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isOn ? 'ON' : 'OFF',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
          color: isOn ? Colors.white : const Color(0xFF111111),
        ),
      ),
    );
  }
}
