//room_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/home_provider.dart';
import '../widgets/stylish_background.dart';
import '../widgets/device_tile.dart';

class RoomPage extends StatefulWidget {
  const RoomPage({super.key, required this.roomId});

  final String roomId;

  @override
  State<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> {
  @override
  void initState() {
    super.initState();
    // Si l'app est ouverte direct sur RoomPage, on s'assure que state est chargé
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

            final room = _firstWhereOrNull(vm.rooms, (r) => r.id == widget.roomId);
            if (room == null) {
              return const Center(child: Text('Room not found'));
            }

            final totalDevices =
                vm.rooms.fold<int>(0, (sum, r) => sum + r.devices.length);
            final ratio = totalDevices == 0
                ? 0.25
                : (vm.activeDevicesCount / totalDevices).clamp(0.0, 1.0);

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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  room.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF111111),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${room.devices.length} appareils',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _RoomIcon(roomImage: room.image),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Small info cards (temp/energy/global active)
                      Row(
                        children: [
                          Expanded(
                            child: _InfoChip(
                              title: 'Temp.',
                              value: '${vm.temperature.toStringAsFixed(1)}°C',
                              icon: Icons.thermostat_outlined,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _InfoChip(
                              title: 'Énergie',
                              value: '${vm.energy.toStringAsFixed(1)} kWh',
                              icon: Icons.bolt_outlined,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      const Text(
                        'Appareils',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111111),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Expanded(
                        child: GridView.builder(
                          itemCount: room.devices.length,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: 1.05,
                          ),
                          itemBuilder: (context, i) {
                            final d = room.devices[i];
                            return DeviceTile(roomId: room.id, device: d);
                          },
                        ),
                      ),
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
}

/// Petit widget pour l'image de la pièce (room.image)
class _RoomIcon extends StatelessWidget {
  const _RoomIcon({required this.roomImage});

  final String roomImage;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 10),
          )
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: Image.asset(
        roomImage,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.home_outlined, color: Color(0xFF111111)),
      ),
    );
  }
}

/// Petite carte info
class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F3F7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: const Color(0xFF111111)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111111),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

/// Utilitaire: firstWhereOrNull sans package
T? _firstWhereOrNull<T>(Iterable<T> items, bool Function(T) test) {
  for (final x in items) {
    if (test(x)) return x;
  }
  return null;
}
