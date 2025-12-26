import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/home_state.dart';
import '../models/device.dart';

class SimulationService {
  SimulationService({this.assetPath = 'assets/data/home_state.json'});
  final String assetPath;

  HomeState? _cache;

  Future<HomeState> fetchHomeState() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString(assetPath);
    final map = jsonDecode(raw) as Map<String, dynamic>;
    _cache = HomeState.fromJson(map);
    return _cache!;
  }

  HomeState? get currentState => _cache;

  Future<HomeState> toggleDevice(String deviceId) async {
    final state = await fetchHomeState();
    _cache = _updateDevice(state, deviceId, (d) => d.copyWith(isOn: !d.isOn));
    return _cache!;
  }

  Future<HomeState> setDeviceLevel(String deviceId, double level) async {
    final state = await fetchHomeState();
    final v = level.clamp(0, 100).toDouble();
    _cache = _updateDevice(state, deviceId, (d) => d.copyWith(level: v));
    return _cache!;
  }

  Future<HomeState> setDeviceTemp(String deviceId, double temp) async {
    final state = await fetchHomeState();
    final v = temp.clamp(16, 30).toDouble();
    _cache = _updateDevice(state, deviceId, (d) => d.copyWith(temp: v));
    return _cache!;
  }

  Future<HomeState> setDeviceMode(String deviceId, String mode) async {
    final state = await fetchHomeState();
    _cache = _updateDevice(state, deviceId, (d) => d.copyWith(mode: mode));
    return _cache!;
  }

  HomeState _updateDevice(
    HomeState state,
    String deviceId,
    Device Function(Device old) updater,
  ) {
    final updatedRooms = state.rooms.map((room) {
      final updatedDevices = room.devices.map((dev) {
        if (dev.id == deviceId) return updater(dev);
        return dev;
      }).toList();
      return room.copyWith(devices: updatedDevices);
    }).toList();

    return state.copyWith(rooms: updatedRooms);
  }
}
