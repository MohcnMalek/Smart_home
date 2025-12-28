//home_provider
import 'dart:async';
import 'dart:math';
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

  // ✅ Historique des événements (Logs)
  final List<String> eventLogs = [];

  // ✅ Phrase à prononcer après commande vocale
  String? lastVoiceFeedback;

  // ✅ Liste des exemples wajdine (Ready-to-use) pour le bouton "Aide"
  final List<Map<String, String>> voiceHelpExamples = [
    {"title": "Living Room", "cmd": "Turn on the living room light"},
    {"title": "Bedroom", "cmd": "Switch off the bedroom AC"},
    {"title": "Kitchen", "cmd": "Turn on the kitchen light"},
    {"title": "Garage", "cmd": "Open the garage door"},
    {"title": "Night Mode", "cmd": "Activate night mode"},
    {"title": "All Devices", "cmd": "Turn off all the lights"},
  ];

  // ✅ Énergie "instantanée" (kW) calculée
  double _energyKw = 0.0;
  double get energy => _energyKw;

  // ✅ Courbe énergie (dernières 60 valeurs)
  final List<double> energyHistory = [];

  Timer? _energyTimer;

  // --- Helper: Ajouter un Log ---
  void _addLog(String action) {
    final now = DateTime.now();
    final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    eventLogs.insert(0, "$action ($timeStr)"); 
    if (eventLogs.length > 30) eventLogs.removeLast();
    notifyListeners();
  }

  // -------------------------- LOAD --------------------------
  Future<void> loadHome() async {
    try {
      isLoading = true;
      error = null;
      notifyListeners();

      state = await service.fetchHomeState();

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

  List<Room> get rooms => state?.rooms ?? [];
  double get temperature => state?.temperature ?? 0.0;

  int get activeDevicesCount {
    if (state == null) return 0;
    return rooms.fold(0, (sum, room) => 
      sum + room.devices.where((d) => d.isOn).length
    );
  }

  // -------------------------- ACTIONS --------------------------
  
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
    if (device != null) {
      _addLog("${device.name} level: ${level.round()}%");
    }
    state = await service.setDeviceLevel(deviceId, level);
    _pushEnergySample();
    notifyListeners();
  }

  Future<void> setDeviceTemp(String deviceId, double temp) async {
    final device = _findDevice(deviceId);
    if (device != null) {
      _addLog("${device.name} temp: ${temp.round()}°C");
    }
    state = await service.setDeviceTemp(deviceId, temp);
    _pushEnergySample();
    notifyListeners();
  }

  Future<void> setDeviceMode(String deviceId, String mode) async {
    state = await service.setDeviceMode(deviceId, mode);
    _pushEnergySample();
    notifyListeners();
  }

  // ✅ Scène "Mode Nuit"
  Future<void> activateNightMode() async {
    if (state == null) return;

    _addLog("Scene: Night Mode Activated");

    final updatedRooms = state!.rooms.map((room) {
      final updatedDevices = room.devices.map((device) {
        if (device.type == 'camera') return device.copyWith(isOn: true);
        if (['light', 'tv', 'socket'].contains(device.type)) return device.copyWith(isOn: false);
        if (['curtain', 'garage_door'].contains(device.type)) return device.copyWith(isOn: false);
        if (device.type == 'ac') return device.copyWith(isOn: true, temp: 24.0, mode: 'auto');
        return device;
      }).toList();
      return room.copyWith(devices: updatedDevices);
    }).toList();

    state = state!.copyWith(rooms: updatedRooms);
    _pushEnergySample();
    notifyListeners();
  }

  // -------------------------- VOICE COMMAND --------------------------
  
  Future<bool> runVoiceCommand(String spoken) async {
    lastVoiceFeedback = null;
    if (state == null) return false;

    final s = _normalize(spoken);

    // ✅ Detection "Help" direct f l-voix
    if (_containsAny(s, ['help', 'aide', 'what can i say'])) {
      lastVoiceFeedback = "You can check the help button for examples like 'Turn on the lights'.";
      notifyListeners();
      return false;
    }

    final wantsOn = _containsAny(s, ['turn on', 'switch on', 'power on', 'enable', 'activate', 'allume', 'ouvrir']);
    final wantsOff = _containsAny(s, ['turn off', 'switch off', 'power off', 'disable', 'deactivate', 'éteins', 'fermer']);

    if (!wantsOn && !wantsOff) {
      lastVoiceFeedback = "Action not recognized. Try 'Turn on' or 'Turn off'.";
      notifyListeners();
      return false;
    }

    String? roomId;
    if (_containsAny(s, ['living room', 'salon'])) roomId = 'living_room';
    else if (_containsAny(s, ['bedroom', 'chambre'])) roomId = 'bedroom';
    else if (_containsAny(s, ['kitchen', 'cuisine'])) roomId = 'kitchen';

    String? type;
    if (_containsAny(s, ['light', 'lumière', 'lamp', 'bulb'])) type = 'light';
    else if (_containsAny(s, ['tv', 'télé'])) type = 'tv';
    else if (_containsAny(s, ['ac', 'clim', 'air conditioning'])) type = 'ac';
    else if (_containsAny(s, ['garage', 'door'])) type = 'garage_door';

    bool changedSomething = false;

    // ✅ Gestion spéciale "All Devices"
    bool allDevices = _containsAny(s, ['all', 'tout', 'tous']);

    for (final r in rooms) {
      if (roomId != null && r.id != roomId && !allDevices) continue;
      for (final d in r.devices) {
        if (type != null && d.type != type && !allDevices) continue;

        final shouldChange = (wantsOn && !d.isOn) || (wantsOff && d.isOn);
        if (shouldChange) {
          state = await service.toggleDevice(d.id);
          changedSomething = true;
          _addLog("Voice: ${d.name} ${wantsOn ? 'ON' : 'OFF'}");
        }
      }
    }

    if (changedSomething) {
      lastVoiceFeedback = "Action completed successfully!";
      _pushEnergySample();
      notifyListeners();
      return true;
    } else {
      lastVoiceFeedback = "I couldn't find any device matching your request.";
      notifyListeners();
      return false;
    }
  }

  // -------------------------- ENERGY & TEMP LOGIC --------------------------
  
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
    double currentTemp = state!.temperature;
    bool acOn = false;
    double acTarget = 22.0;

    for (var r in rooms) {
      for (var d in r.devices) {
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
          case 'light': sum += 0.05 * ((d.level ?? 100) / 100); break;
          case 'tv': sum += 0.15; break;
          case 'ac': sum += (d.mode == 'heat') ? 1.5 : 1.0; break;
          case 'socket': sum += 0.20; break;
          case 'garage_door': sum += 0.10; break;
          default: sum += 0.05;
        }
      }
    }
    return sum;
  }

  // -------------------------- HELPERS --------------------------

  Device? _findDevice(String id) {
    for (var r in rooms) {
      for (var d in r.devices) {
        if (d.id == id) return d;
      }
    }
    return null;
  }

  String _normalize(String input) => input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]+'), ' ').trim();
  bool _containsAny(String s, List<String> keys) => keys.any((k) => s.contains(k));

  @override
  void dispose() {
    _energyTimer?.cancel();
    super.dispose();
  }
}