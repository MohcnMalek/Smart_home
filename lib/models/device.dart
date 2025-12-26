import 'package:flutter/material.dart';

class Device {
  final String id;
  final String name;
  final String type;

  final bool isOn;

  // Optionnels selon le type
  final double? level; // light/curtain (0..100)
  final double? temp;  // ac (16..30)
  final String? mode;  // ac: cool/auto/heat...

  const Device({
    required this.id,
    required this.name,
    required this.type,
    required this.isOn,
    this.level,
    this.temp,
    this.mode,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? 'unknown',
      isOn: (json['isOn'] == true),
      level: (json['level'] == null) ? null : (json['level'] as num).toDouble(),
      temp: (json['temp'] == null) ? null : (json['temp'] as num).toDouble(),
      mode: json['mode']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'isOn': isOn,
        if (level != null) 'level': level,
        if (temp != null) 'temp': temp,
        if (mode != null) 'mode': mode,
      };

  Device copyWith({
    String? id,
    String? name,
    String? type,
    bool? isOn,
    double? level,
    double? temp,
    String? mode,
  }) {
    return Device(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      isOn: isOn ?? this.isOn,
      level: level ?? this.level,
      temp: temp ?? this.temp,
      mode: mode ?? this.mode,
    );
  }

  /// ✅ Pour éviter l’erreur "icon not found"
  IconData get icon {
    switch (type) {
      case 'light':
        return Icons.lightbulb_outline;
      case 'tv':
        return Icons.tv;
      case 'ac':
        return Icons.ac_unit;
      case 'curtain':
        return Icons.blinds;
      case 'socket':
        return Icons.power_outlined;
      case 'camera':
        return Icons.videocam_outlined;
      case 'garage_door':
        return Icons.garage_outlined;
      default:
        return Icons.devices_other;
    }
  }

  /// ✅ Pour afficher une image même si ton JSON device n’a pas "image"
  /// Mets tes images ici : assets/images/devices/...
  String get imagePath {
    switch (type) {
      case 'light':
        return 'assets/images/devices/light.png';
      case 'tv':
        return 'assets/images/devices/tv.png';
      case 'ac':
        return 'assets/images/devices/ac.png';
      case 'curtain':
        return 'assets/images/devices/curtain.png';
      case 'socket':
        return 'assets/images/devices/socket.png';
      case 'camera':
        return 'assets/images/devices/camera.png';
      case 'garage_door':
        return 'assets/images/devices/garage.png';
      default:
        return 'assets/images/devices/device.png';
    }
  }
}
