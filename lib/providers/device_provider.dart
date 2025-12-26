import 'package:flutter/foundation.dart';

import '../services/simulation_service.dart';
import 'home_provider.dart';

class DeviceProvider extends ChangeNotifier {
  DeviceProvider({
    required this.service,
    required this.home,
  });

  final SimulationService service;
  final HomeProvider home;

  Future<void> toggle(String deviceId) async {
    final newState = await service.toggleDevice(deviceId);
    home.state = newState;
    home.error = null;
    home.isLoading = false;
    home.notifyListeners();
    notifyListeners();
  }

  Future<void> setLevel(String deviceId, double level) async {
    final newState = await service.setDeviceLevel(deviceId, level);
    home.state = newState;
    home.notifyListeners();
    notifyListeners();
  }

  Future<void> setTemp(String deviceId, double temp) async {
    final newState = await service.setDeviceTemp(deviceId, temp);
    home.state = newState;
    home.notifyListeners();
    notifyListeners();
  }

  Future<void> setMode(String deviceId, String mode) async {
    final newState = await service.setDeviceMode(deviceId, mode);
    home.state = newState;
    home.notifyListeners();
    notifyListeners();
  }
}
