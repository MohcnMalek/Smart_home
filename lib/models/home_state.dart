import 'room.dart';

class HomeState {
  final double temperature; // global
  final double energy; // global
  final List<Room> rooms;

  const HomeState({
    required this.temperature,
    required this.energy,
    required this.rooms,
  });

  HomeState copyWith({
    double? temperature,
    double? energy,
    List<Room>? rooms,
  }) {
    return HomeState(
      temperature: temperature ?? this.temperature,
      energy: energy ?? this.energy,
      rooms: rooms ?? this.rooms,
    );
  }

  factory HomeState.fromJson(Map<String, dynamic> json) {
    final list = (json['rooms'] as List<dynamic>? ?? []);
    return HomeState(
      temperature: (json['temperature'] is num) ? (json['temperature'] as num).toDouble() : 22.0,
      energy: (json['energy'] is num) ? (json['energy'] as num).toDouble() : 3.2,
      rooms: list.map((e) => Room.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'temperature': temperature,
        'energy': energy,
        'rooms': rooms.map((r) => r.toJson()).toList(),
      };
}
