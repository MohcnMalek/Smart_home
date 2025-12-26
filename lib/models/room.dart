import 'device.dart';

class Room {
  final String id;
  final String name;
  final String image; // ✅ ton JSON utilise "image"
  final List<Device> devices;

  const Room({
    required this.id,
    required this.name,
    required this.image,
    required this.devices,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    final rawDevices = (json['devices'] as List? ?? []);
    return Room(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      image: json['image']?.toString() ?? '',
      devices: rawDevices.map((e) => Device.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'image': image,
        'devices': devices.map((d) => d.toJson()).toList(),
      };

  Room copyWith({
    String? id,
    String? name,
    String? image,
    List<Device>? devices,
  }) {
    return Room(
      id: id ?? this.id,
      name: name ?? this.name,
      image: image ?? this.image,
      devices: devices ?? this.devices,
    );
  }
}
