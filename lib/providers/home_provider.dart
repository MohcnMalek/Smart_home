import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/home_state.dart';
import '../models/room.dart';
import '../models/device.dart';
import '../services/simulation_service.dart';

class HomeProvider extends ChangeNotifier {
  final SimulationService service;
  HomeProvider({required this.service});

  HomeState? state;
  bool isLoading = false;
  String? error;

  // ===== ENERGY (dynamic) =====
  Timer? _energyTimer;
  DateTime? _lastTick;
  double _energyTotalKwh = 0.0;

  final List<double> _energyHistory = [];
  List<double> get energyHistory => List.unmodifiable(_energyHistory);

  List<Room> get rooms => state?.rooms ?? [];

  double get temperature => state?.temperature ?? 0.0;

  /// ✅ énergie totale consommée (kWh) qui augmente avec le temps
  double get energy => double.parse(_energyTotalKwh.toStringAsFixed(2));

  /// ✅ puissance instantanée (kW) selon devices ON/OFF
  double get powerKw => double.parse(_computePowerKw().toStringAsFixed(2));

  int get activeDevicesCount {
    int count = 0;
    for (final r in rooms) {
      for (final d in r.devices) {
        if (d.isOn) count++;
      }
    }
    return count;
  }

  Future<void> loadHome() async {
    try {
      isLoading = true;
      error = null;
      notifyListeners();

      state = await service.fetchHomeState();

      // base from JSON (ex: 3.2 kWh)
      _energyTotalKwh = state?.energy ?? 0.0;
      _lastTick = DateTime.now();
      _pushEnergySample(); // first point

      // start ticker (histogram will move)
      startEnergyTicker();
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Room? roomById(String roomId) {
    for (final r in rooms) {
      if (r.id.toString() == roomId) return r;
    }
    return null;
  }

  // ======= ACTIONS =======
  Future<void> toggleDevice(String deviceId) async {
    state = await service.toggleDevice(deviceId);
    // immediate sample after action
    _pushEnergySample();
    notifyListeners();
  }

  Future<void> setDeviceLevel(String deviceId, double level) async {
    state = await service.setDeviceLevel(deviceId, level);
    _pushEnergySample();
    notifyListeners();
  }

  Future<void> setDeviceTemp(String deviceId, double temp) async {
    state = await service.setDeviceTemp(deviceId, temp);
    _pushEnergySample();
    notifyListeners();
  }

  Future<void> setDeviceMode(String deviceId, String mode) async {
    state = await service.setDeviceMode(deviceId, mode);
    _pushEnergySample();
    notifyListeners();
  }

  // ===========================================================
  // ✅ ENERGY TICKER: makes histogram move automatically
  // ===========================================================
  void startEnergyTicker({Duration interval = const Duration(seconds: 2)}) {
    if (_energyTimer != null) return;

    _lastTick ??= DateTime.now();

    _energyTimer = Timer.periodic(interval, (_) {
      if (state == null) return;

      final now = DateTime.now();
      final last = _lastTick ?? now;
      final dtSeconds = now.difference(last).inMilliseconds / 1000.0;
      _lastTick = now;

      // kWh += kW * hours
      final dtHours = dtSeconds / 3600.0;
      _energyTotalKwh += _computePowerKw() * dtHours;

      _pushEnergySample();
      notifyListeners();
    });
  }

  void stopEnergyTicker() {
    _energyTimer?.cancel();
    _energyTimer = null;
  }

  @override
  void dispose() {
    stopEnergyTicker();
    super.dispose();
  }

  // ======= ENERGY HELPERS =======
  double _computePowerKw() {
    double sum = 0;
    for (final r in rooms) {
      for (final d in r.devices) {
        if (!d.isOn) continue;
        sum += _powerForDevice(d);
      }
    }
    return sum;
  }

  double _powerForDevice(Device d) {
    switch (d.type) {
      case 'light':
        final level = (d.level ?? 100).clamp(0, 100).toDouble();
        return 0.06 * (level / 100.0); // up to 0.06 kW (60W)

      case 'tv':
        return 0.12; // 120W

      case 'ac':
        return 1.50; // 1500W

      case 'curtain':
        final level = (d.level ?? 50).clamp(0, 100).toDouble();
        return 0.02 * (level / 100.0); // small motor usage

      case 'socket':
        return 0.10; // 100W average simulated

      case 'camera':
        return 0.05; // 50W

      case 'garage_door':
        return 0.20; // simulated motor

      default:
        return 0.08;
    }
  }

  void _pushEnergySample() {
    // push current total kWh (you can also push powerKw if you prefer)
    _energyHistory.add(energy);
    if (_energyHistory.length > 12) _energyHistory.removeAt(0);
  }

  // ===========================================================
  // ✅ VOICE COMMAND (your existing code) — keep it here
  // ===========================================================
  Future<bool> runVoiceCommand(String spoken) async {
    if (state == null) return false;

    final s = _normalize(spoken);

    final wantsOn = _containsAny(s, const [
      'turn on',
      'switch on',
      'power on',
      'enable',
      'activate',
      'lights on',
    ]);

    final wantsOff = _containsAny(s, const [
      'turn off',
      'switch off',
      'power off',
      'disable',
      'deactivate',
      'lights off',
    ]);

    if (!wantsOn && !wantsOff) return false;
    final desiredOn = wantsOn && !wantsOff;

    String? roomId;
    if (_containsAny(s, const ['living room', 'livingroom', 'lounge'])) {
      roomId = 'living_room';
    } else if (_containsAny(s, const ['bedroom'])) {
      roomId = 'bedroom';
    } else if (_containsAny(s, const ['kitchen'])) {
      roomId = 'kitchen';
    } else if (_containsAny(s, const ['garage'])) {
      roomId = 'garage';
    }

    String? type;
    if (_containsAny(s, const ['light', 'lights', 'lamp'])) {
      type = 'light';
    } else if (_containsAny(s, const ['tv', 'television'])) {
      type = 'tv';
    } else if (_containsAny(s, const ['ac', 'air conditioner', 'airconditioning'])) {
      type = 'ac';
    } else if (_containsAny(s, const ['curtain', 'curtains', 'blind', 'blinds'])) {
      type = 'curtain';
    } else if (_containsAny(s, const ['socket', 'outlet', 'plug'])) {
      type = 'socket';
    } else if (_containsAny(s, const ['camera', 'cam'])) {
      type = 'camera';
    } else if (_containsAny(s, const ['garage door'])) {
      type = 'garage_door';
    }

    if (roomId == null && type == null) return false;

    for (final r in rooms) {
      if (roomId != null && r.id != roomId) continue;

      for (final d in r.devices) {
        if (type != null && d.type != type) continue;

        if (d.isOn == desiredOn) {
          // already OK
          return true;
        }

        state = await service.toggleDevice(d.id);
        _pushEnergySample();
        notifyListeners();
        return true;
      }
    }

    return false;
  }

  String _normalize(String input) {
    var s = input.toLowerCase();
    s = s.replaceAll(RegExp(r'[^a-z0-9\s]+'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  bool _containsAny(String s, List<String> keys) {
    for (final k in keys) {
      if (s.contains(k)) return true;
    }
    return false;
  }
}
