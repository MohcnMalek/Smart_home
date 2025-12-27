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

  // ✅ phrase à prononcer après commande vocale
  String? lastVoiceFeedback;

  // ✅ énergie "instantanée" (kW) calculée depuis devices ON/OFF
  double _energyKw = 0.0;
  double get energy => _energyKw;

  // ✅ courbe énergie (dernières 60 valeurs)
  final List<double> energyHistory = [];

  Timer? _energyTimer;

  // -------------------------- LOAD --------------------------
  Future<void> loadHome() async {
    try {
      isLoading = true;
      error = null;
      notifyListeners();

      state = await service.fetchHomeState();

      _pushEnergySample();      // 1er point
      _startEnergyTimer();      // ✅ fait bouger la courbe en continu
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  List<Room> get rooms => state?.rooms ?? [];
  double get temperature => state?.temperature ?? 0.0;

  int get activeDevicesCount {
    int count = 0;
    for (final r in rooms) {
      for (final d in r.devices) {
        if (d.isOn) count++;
      }
    }
    return count;
  }

  Room? roomById(String roomId) {
    for (final r in rooms) {
      if (r.id.toString() == roomId) return r;
    }
    return null;
  }

  // -------------------------- ACTIONS --------------------------
  Future<void> toggleDevice(String deviceId) async {
    state = await service.toggleDevice(deviceId);
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
  // ✅ BONUS: English voice command + feedback
  // ===========================================================
  Future<bool> runVoiceCommand(String spoken) async {
    lastVoiceFeedback = null;
    if (state == null) return false;

    final s = _normalize(spoken);

    // ACTION
    final wantsOn = _containsAny(s, const [
      'turn on',
      'switch on',
      'power on',
      'enable',
      'activate',
    ]);
    final wantsOff = _containsAny(s, const [
      'turn off',
      'switch off',
      'power off',
      'disable',
      'deactivate',
    ]);

    if (!wantsOn && !wantsOff) {
      lastVoiceFeedback = "Sorry, I didn't catch ON or OFF.";
      return false;
    }

    // ROOM
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

    // DEVICE TYPE
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
    } else if (_containsAny(s, const ['garage door', 'door'])) {
      type = 'garage_door';
    }

    if (roomId == null && type == null) {
      lastVoiceFeedback = "Sorry, I couldn't find the room or device type.";
      return false;
    }

    // ✅ "all" support (optional)
    final wantsAll = _containsAny(s, const ['all', 'everything']);

    bool changedSomething = false;

    for (final r in rooms) {
      if (roomId != null && r.id != roomId) continue;

      for (final d in r.devices) {
        if (type != null && d.type != type) continue;

        final shouldToggle = (wantsOn && !d.isOn) || (wantsOff && d.isOn);
        if (shouldToggle) {
          state = await service.toggleDevice(d.id);
          changedSomething = true;
          if (!wantsAll) {
            _pushEnergySample();
            notifyListeners();
            lastVoiceFeedback = "Of course. ${_roomLabel(r.id)} ${_deviceLabel(d.type)} is now ${wantsOn ? 'ON' : 'OFF'}.";
            return true;
          }
        }

        if (!wantsAll) {
          // already correct state
          lastVoiceFeedback = "Of course. ${_roomLabel(r.id)} ${_deviceLabel(d.type)} is already ${d.isOn ? 'ON' : 'OFF'}.";
          return true;
        }
      }
    }

    if (changedSomething) {
      _pushEnergySample();
      notifyListeners();
      lastVoiceFeedback = "Of course. Done.";
      return true;
    }

    lastVoiceFeedback = "Sorry, I couldn't find that device.";
    return false;
  }

  // -------------------------- ENERGY --------------------------
  void _startEnergyTimer() {
    _energyTimer?.cancel();
    _energyTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state == null) return;
      _pushEnergySample();
      notifyListeners(); // ✅ fait bouger la courbe
    });
  }

  void _pushEnergySample() {
    _energyKw = _computeEnergyKw();

    energyHistory.add(_energyKw);
    if (energyHistory.length > 60) {
      energyHistory.removeAt(0);
    }
  }

  double _computeEnergyKw() {
    if (state == null) return 0.0;

    double sum = 0.0;

    for (final room in rooms) {
      for (final d in room.devices) {
        if (!d.isOn) continue;

        switch (d.type) {
          case 'light':
            // 0.06 kW max * level
            sum += 0.06 * ((d.level ?? 100) / 100.0);
            break;

          case 'tv':
            sum += 0.12;
            break;

          case 'ac':
            // base 1.2 kW, mode fan smaller
            final mode = (d.mode ?? 'auto').toLowerCase();
            final factor = (mode == 'fan') ? 0.55 : 1.0;
            sum += 1.20 * factor;
            break;

          case 'curtain':
            // petit moteur
            sum += 0.02 * ((d.level ?? 50) / 100.0);
            break;

          case 'socket':
            sum += 0.10;
            break;

          case 'camera':
            sum += 0.08;
            break;

          case 'garage_door':
            sum += 0.15;
            break;

          default:
            sum += 0.05;
        }
      }
    }

    return sum;
  }

  // ---------------- helpers ----------------
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

  String _roomLabel(String roomId) {
    switch (roomId) {
      case 'living_room':
        return 'Living room';
      case 'bedroom':
        return 'Bedroom';
      case 'kitchen':
        return 'Kitchen';
      case 'garage':
        return 'Garage';
      default:
        return roomId;
    }
  }

  String _deviceLabel(String type) {
    switch (type) {
      case 'light':
        return 'light';
      case 'tv':
        return 'TV';
      case 'ac':
        return 'air conditioner';
      case 'curtain':
        return 'curtains';
      case 'socket':
        return 'socket';
      case 'camera':
        return 'camera';
      case 'garage_door':
        return 'garage door';
      default:
        return type;
    }
  }

  @override
  void dispose() {
    _energyTimer?.cancel();
    super.dispose();
  }
}
