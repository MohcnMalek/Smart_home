import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/home_provider.dart';
import '../widgets/stylish_background.dart';
import 'phone_camera_page.dart';

class DeviceControlPage extends StatefulWidget {
  const DeviceControlPage({
    super.key,
    required this.roomId,
    required this.deviceId,
  });

  final String roomId;
  final String deviceId;

  @override
  State<DeviceControlPage> createState() => _DeviceControlPageState();
}

class _DeviceControlPageState extends State<DeviceControlPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final home = context.read<HomeProvider>();
      if (home.state == null && !home.isLoading) {
        home.loadHome();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: Consumer<HomeProvider>(
          builder: (context, vm, _) {
            if (vm.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (vm.error != null) {
              return Center(child: Text('Error: ${vm.error}'));
            }

            // Room
            final room = _firstWhereOrNull(vm.rooms, (r) => r.id == widget.roomId);
            if (room == null) {
              return const Center(child: Text('Room not found'));
            }

            // Device
            final device = _firstWhereOrNull(room.devices, (d) => d.id == widget.deviceId);
            if (device == null) {
              return const Center(child: Text('Device not found'));
            }

            final totalDevices =
                vm.rooms.fold<int>(0, (sum, r) => sum + r.devices.length);
            final ratio = totalDevices == 0
                ? 0.25
                : (vm.activeDevicesCount / totalDevices).clamp(0.0, 1.0);

            final isOn = device.isOn;

            return Stack(
              children: [
                StylishBackground(intensity: ratio, hueShift: 0.0),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back_ios_new_rounded),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              device.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF111111),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          _DeviceIcon(device: device),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Main card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
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
                            // ON/OFF row
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _labelType(device.type),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ),
                                Switch(
                                  value: isOn,
                                  onChanged: (_) => vm.toggleDevice(device.id),
                                  activeColor: const Color(0xFF111827),
                                  activeTrackColor: const Color(0xFF111827).withValues(alpha: 0.15),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isOn ? 'ON' : 'OFF',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: isOn ? const Color(0xFF111827) : const Color(0xFF6B7280),
                              ),
                            ),

                            const SizedBox(height: 14),

                            // Controls by type
                            if (device.type == 'light' || device.type == 'curtain') ...[
                              _LevelControl(
                                title: device.type == 'light' ? 'Intensité' : 'Ouverture',
                                value: (device.level ?? 50).clamp(0, 100).toDouble(),
                                onChanged: (v) => vm.service.setDeviceLevel(device.id, v),
                                onChangeEnd: () async {
                                  vm.state = await vm.service.fetchHomeState();
                                  vm.notifyListeners();
                                },
                              ),
                            ],

                            if (device.type == 'ac') ...[
                              _TempControl(
                                temp: (device.temp ?? 24).clamp(16, 30).toDouble(),
                                mode: device.mode ?? 'auto',
                                onTempChanged: (v) async {
                                  await vm.service.setDeviceTemp(device.id, v);
                                  vm.state = await vm.service.fetchHomeState();
                                  vm.notifyListeners();
                                },
                                onModeChanged: (m) async {
                                  await vm.service.setDeviceMode(device.id, m);
                                  vm.state = await vm.service.fetchHomeState();
                                  vm.notifyListeners();
                                },
                              ),
                            ],

                            if (device.type == 'camera') ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const PhoneCameraPage()),
                                    );
                                  },
                                  child: const Text("Ouvrir la caméra"),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Room info small
                      _MiniRoomCard(
                        roomName: room.name,
                        devicesCount: room.devices.length,
                      ),

                      const Spacer(),
                    ],
                  ),
                ),
              ],
            );
          },
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

class _DeviceIcon extends StatelessWidget {
  const _DeviceIcon({required this.device});

  final dynamic device;

  @override
  Widget build(BuildContext context) {
    // imagePath optionnel
    final String img = (device.imagePath ?? '').toString();
    final bool hasImage = img.isNotEmpty;

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 10),
          )
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: hasImage
          ? Image.asset(
              img,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  Icon(device.icon, color: const Color(0xFF111111)),
            )
          : Icon(device.icon, color: const Color(0xFF111111)),
    );
  }
}

class _MiniRoomCard extends StatelessWidget {
  const _MiniRoomCard({
    required this.roomName,
    required this.devicesCount,
  });

  final String roomName;
  final int devicesCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.meeting_room_outlined, color: Color(0xFF111111)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              roomName,
              style: const TextStyle(fontWeight: FontWeight.w900),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '$devicesCount appareils',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelControl extends StatefulWidget {
  const _LevelControl({
    required this.title,
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final String title;
  final double value;
  final ValueChanged<double> onChanged;
  final Future<void> Function() onChangeEnd;

  @override
  State<_LevelControl> createState() => _LevelControlState();
}

class _LevelControlState extends State<_LevelControl> {
  late double _v;

  @override
  void initState() {
    super.initState();
    _v = widget.value;
  }

  @override
  void didUpdateWidget(covariant _LevelControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.value - widget.value).abs() > 0.1) {
      _v = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111111),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: _v.clamp(0, 100),
                min: 0,
                max: 100,
                divisions: 100,
                onChanged: (x) {
                  setState(() => _v = x);
                  widget.onChanged(x);
                },
                onChangeEnd: (_) async {
                  await widget.onChangeEnd();
                },
              ),
            ),
            SizedBox(
              width: 48,
              child: Text(
                '${_v.round()}%',
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            )
          ],
        ),
      ],
    );
  }
}

class _TempControl extends StatelessWidget {
  const _TempControl({
    required this.temp,
    required this.mode,
    required this.onTempChanged,
    required this.onModeChanged,
  });

  final double temp;
  final String mode;
  final ValueChanged<double> onTempChanged;
  final ValueChanged<String> onModeChanged;

  @override
  Widget build(BuildContext context) {
    const modes = ['auto', 'cool', 'heat', 'fan'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Température',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111111),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: temp.clamp(16, 30),
                min: 16,
                max: 30,
                divisions: 14,
                onChanged: onTempChanged,
              ),
            ),
            SizedBox(
              width: 54,
              child: Text(
                '${temp.round()}°C',
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            )
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'Mode',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111111),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          children: modes.map((m) {
            final selected = m == mode;
            return ChoiceChip(
              label: Text(m),
              selected: selected,
              onSelected: (_) => onModeChanged(m),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// Utilitaire sans package
T? _firstWhereOrNull<T>(Iterable<T> items, bool Function(T) test) {
  for (final x in items) {
    if (test(x)) return x;
  }
  return null;
}
