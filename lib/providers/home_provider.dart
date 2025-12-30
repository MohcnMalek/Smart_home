import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

import '../models/home_state.dart';
import '../models/room.dart';
import '../models/device.dart';
import '../services/simulation_service.dart';
import '../services/sqlite_cache_service.dart';

class HomeProvider extends ChangeNotifier {
  final SimulationService service;
  final SqliteCacheService db;

  HomeProvider({
    required this.service,
    required this.db,
  });

  HomeState? state;
  bool isLoading = false;
  String? error;

  // ✅ Historique (Dashboard > History)
  final List<String> eventLogs = [];

  // ✅ Feedback après voice command
  String? lastVoiceFeedback;

  // ✅ Exemples
  final List<Map<String, String>> voiceHelpExamples = const [
    {"title": "Living Room", "cmd": "Turn on the living room light"},
    {"title": "Bedroom", "cmd": "Switch off the bedroom AC"},
    {"title": "Kitchen", "cmd": "Turn on the kitchen light"},
    {"title": "Garage", "cmd": "Open the garage door"},
    {"title": "Night Mode", "cmd": "Activate night mode"},
    {"title": "All Devices", "cmd": "Turn off all the lights"},
  ];

  // ✅ Energie
  double _energyKw = 0.0;
  double get energy => _energyKw;

  final List<double> energyHistory = [];
  Timer? _energyTimer;

  // ===========================================================
  // LOGS (IMPORTANT: non-bloquant)
  // ===========================================================
  void _addLog(String action) {
    final now = DateTime.now();
    final timeStr =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    final line = "$action ($timeStr)";

    eventLogs.insert(0, line);
    if (eventLogs.length > 30) eventLogs.removeLast();

    notifyListeners();

    // ✅ Sauvegarde SQLite en "background" (sans await)
    db.saveLogLine(line);
  }

  // ===========================================================
  // LOAD
  // ===========================================================
  Future<void> loadHome() async {
    try {
      isLoading = true;
      error = null;
      notifyListeners();

      state = await service.fetchHomeState();

      // logs depuis SQLite (une seule fois)
      final savedLogs = await db.loadLogs(limit: 30);
      eventLogs
        ..clear()
        ..addAll(savedLogs);

      _pushEnergySample();
      _startEnergyTimer();
      _addLog("System Started");
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ===========================================================
  // GETTERS
  // ===========================================================
  List<Room> get rooms => state?.rooms ?? [];
  double get temperature => state?.temperature ?? 0.0;

  int get activeDevicesCount {
    if (state == null) return 0;
    return rooms.fold<int>(
      0,
      (sum, room) => sum + room.devices.where((d) => d.isOn).length,
    );
  }

  // ===========================================================
  // ACTIONS
  // ===========================================================
  Future<void> toggleDevice(String deviceId) async {
    final device = _findDevice(deviceId);
    if (device != null) {
      final action = device.isOn ? "OFF" : "ON";
      _addLog("$action: ${device.name}");
    }

    state = await service.toggleDevice(deviceId);
    _pushEnergySample();
    notifyListeners();
  }

  Future<void> setDeviceLevel(String deviceId, double level) async {
    final device = _findDevice(deviceId);
    if (device != null) _addLog("${device.name} level: ${level.round()}%");

    state = await service.setDeviceLevel(deviceId, level);
    _pushEnergySample();
    notifyListeners();
  }

  Future<void> setDeviceTemp(String deviceId, double temp) async {
    final device = _findDevice(deviceId);
    if (device != null) _addLog("${device.name} temp: ${temp.round()}°C");

    state = await service.setDeviceTemp(deviceId, temp);
    _pushEnergySample();
    notifyListeners();
  }

  Future<void> setDeviceMode(String deviceId, String mode) async {
    final device = _findDevice(deviceId);
    if (device != null) _addLog("${device.name} mode: $mode");

    state = await service.setDeviceMode(deviceId, mode);
    _pushEnergySample();
    notifyListeners();
  }

  // ===========================================================
  // SCENE: Night Mode
  // ===========================================================
  Future<void> activateNightMode() async {
    if (state == null) return;

    _addLog("Scene: Night Mode Activated");

    final updatedRooms = state!.rooms.map((room) {
      final updatedDevices = room.devices.map((device) {
        if (device.type == 'camera') return device.copyWith(isOn: true);

        if (['light', 'tv', 'socket'].contains(device.type)) {
          return device.copyWith(isOn: false);
        }

        if (['curtain', 'garage_door'].contains(device.type)) {
          return device.copyWith(isOn: false);
        }

        if (device.type == 'ac') {
          return device.copyWith(isOn: true, temp: 24.0, mode: 'auto');
        }

        return device;
      }).toList();

      return room.copyWith(devices: updatedDevices);
    }).toList();

    state = state!.copyWith(rooms: updatedRooms);
    await db.saveHomeState(state!); // une seule sauvegarde
    _pushEnergySample();
    notifyListeners();
  }

  // ===========================================================
  // VOICE COMMAND
  // ===========================================================
  Future<bool> runVoiceCommand(String spoken) async {
    lastVoiceFeedback = null;
    if (state == null) return false;

    final s = _normalize(spoken);

    if (_containsAny(s, const ['help', 'aide', 'what can i say'])) {
      lastVoiceFeedback =
          "You can check the help button for examples like 'Turn on the lights'.";
      notifyListeners();
      return false;
    }

    if (_containsAny(s, const ['night mode', 'mode nuit', 'activate night'])) {
      await activateNightMode();
      lastVoiceFeedback = "Of course. Night mode activated.";
      notifyListeners();
      return true;
    }

    final wantsOn = _containsAny(s, const [
      'turn on',
      'switch on',
      'power on',
      'enable',
      'activate',
      'allume',
      'ouvrir',
      'open',
    ]);

    final wantsOff = _containsAny(s, const [
      'turn off',
      'switch off',
      'power off',
      'disable',
      'deactivate',
      'éteins',
      'fermer',
      'close',
    ]);

    if (!wantsOn && !wantsOff) {
      lastVoiceFeedback = "Action not recognized. Try 'Turn on' or 'Turn off'.";
      notifyListeners();
      return false;
    }

    // room detect
    String? roomId;
    if (_containsAny(s, const ['living room', 'salon'])) roomId = 'living_room';
    else if (_containsAny(s, const ['bedroom', 'chambre'])) roomId = 'bedroom';
    else if (_containsAny(s, const ['kitchen', 'cuisine'])) roomId = 'kitchen';
    else if (_containsAny(s, const ['garage'])) roomId = 'garage';

    // type detect
    String? type;
    if (_containsAny(s, const ['light', 'lumière', 'lamp', 'bulb', 'lights']))
      type = 'light';
    else if (_containsAny(s, const ['tv', 'télé', 'television']))
      type = 'tv';
    else if (_containsAny(s, const ['ac', 'clim', 'air conditioning']))
      type = 'ac';
    else if (_containsAny(s, const ['curtain', 'rideau', 'curtains']))
      type = 'curtain';
    else if (_containsAny(s, const ['camera', 'cam']))
      type = 'camera';
    else if (_containsAny(s, const ['socket', 'plug', 'prise', 'outlet']))
      type = 'socket';
    else if (_containsAny(s, const ['door', 'garage door']))
      type = 'garage_door';

    final allDevices = _containsAny(s, const ['all', 'tout', 'tous', 'everything']);

    bool changed = false;

    for (final r in rooms) {
      if (!allDevices && roomId != null && r.id != roomId) continue;

      for (final d in r.devices) {
        if (!allDevices && type != null && d.type != type) continue;

        final shouldChange = (wantsOn && !d.isOn) || (wantsOff && d.isOn);
        if (shouldChange) {
          state = await service.toggleDevice(d.id);
          changed = true;
          _addLog("Voice: ${d.name} ${wantsOn ? 'ON' : 'OFF'}");
        }
      }
    }

    if (changed) {
      lastVoiceFeedback = "Of course. Action completed successfully!";
      _pushEnergySample();
      notifyListeners();
      return true;
    } else {
      lastVoiceFeedback = "I couldn't find any device matching your request.";
      notifyListeners();
      return false;
    }
  }

  // ===========================================================
  // ENERGY + TEMP
  // ===========================================================
  void _startEnergyTimer() {
    _energyTimer?.cancel();
    _energyTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (state != null) {
        _simulateTemperature();
        _pushEnergySample();
        notifyListeners();
      }
    });
  }

  void _simulateTemperature() {
    if (state == null) return;

    final currentTemp = state!.temperature;
    bool acOn = false;
    double acTarget = 22.0;

    for (final r in rooms) {
      for (final d in r.devices) {
        if (d.type == 'ac' && d.isOn) {
          acOn = true;
          acTarget = d.temp ?? 22.0;
        }
      }
    }

    double newTemp = currentTemp;
    if (acOn) {
      if (currentTemp > acTarget) newTemp -= 0.1;
      else if (currentTemp < acTarget) newTemp += 0.1;
    } else {
      newTemp += (Random().nextDouble() - 0.5) * 0.05;
    }

    state = state!.copyWith(temperature: newTemp);
  }

  void _pushEnergySample() {
    _energyKw = _computeEnergyKw();
    energyHistory.add(_energyKw);
    if (energyHistory.length > 60) energyHistory.removeAt(0);
  }

  double _computeEnergyKw() {
    if (state == null) return 0.0;

    double sum = 0.0;
    for (final r in rooms) {
      for (final d in r.devices) {
        if (!d.isOn) continue;

        switch (d.type) {
          case 'light':
            sum += 0.05 * ((d.level ?? 100) / 100);
            break;
          case 'tv':
            sum += 0.15;
            break;
          case 'ac':
            sum += (d.mode == 'heat') ? 1.5 : 1.0;
            break;
          case 'socket':
            sum += 0.20;
            break;
          case 'garage_door':
            sum += 0.10;
            break;
          default:
            sum += 0.05;
        }
      }
    }
    return sum;
  }

  // ===========================================================
  // HELPERS
  // ===========================================================
  Device? _findDevice(String id) {
    for (final r in rooms) {
      for (final d in r.devices) {
        if (d.id == id) return d;
      }
    }
    return null;
  }

  String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _containsAny(String s, List<String> keys) {
    for (final k in keys) {
      if (s.contains(k)) return true;
    }
    return false;
  }

  @override
  void dispose() {
    _energyTimer?.cancel();
    super.dispose();
  }
}
