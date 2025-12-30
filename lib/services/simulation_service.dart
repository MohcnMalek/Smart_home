import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/home_state.dart';
import '../models/device.dart';
import 'sqlite_cache_service.dart';

class SimulationService {
  SimulationService({
    required this.db,
    this.assetPath = 'assets/data/home_state.json',
  });

  final SqliteCacheService db;
  final String assetPath;

  HomeState? _cache;

  Future<HomeState> fetchHomeState() async {
    // 1) cache mémoire
    if (_cache != null) return _cache!;

    // 2) cache SQLite
    final fromDb = await db.loadHomeState();
    if (fromDb != null) {
      _cache = fromDb;
      return _cache!;
    }

    // 3) seed depuis assets JSON
    final raw = await rootBundle.loadString(assetPath);
    final map = jsonDecode(raw) as Map<String, dynamic>;
    _cache = HomeState.fromJson(map);

    await db.saveHomeState(_cache!);
    return _cache!;
  }

  HomeState? get currentState => _cache;

  Future<HomeState> toggleDevice(String deviceId) async {
    final state = await fetchHomeState();
    _cache = _updateDevice(state, deviceId, (d) => d.copyWith(isOn: !d.isOn));
    await db.saveHomeState(_cache!);
    return _cache!;
  }

  Future<HomeState> setDeviceLevel(String deviceId, double level) async {
    final state = await fetchHomeState();
    final v = level.clamp(0, 100).toDouble();
    _cache = _updateDevice(state, deviceId, (d) => d.copyWith(level: v));
    await db.saveHomeState(_cache!);
    return _cache!;
  }

  Future<HomeState> setDeviceTemp(String deviceId, double temp) async {
    final state = await fetchHomeState();
    final v = temp.clamp(16, 30).toDouble();
    _cache = _updateDevice(state, deviceId, (d) => d.copyWith(temp: v));
    await db.saveHomeState(_cache!);
    return _cache!;
  }

  Future<HomeState> setDeviceMode(String deviceId, String mode) async {
    final state = await fetchHomeState();
    _cache = _updateDevice(state, deviceId, (d) => d.copyWith(mode: mode));
    await db.saveHomeState(_cache!);
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

  Future<void> resetToAssets() async {
    _cache = null;
    await db.clearHomeState();
    await fetchHomeState();
  }
}
