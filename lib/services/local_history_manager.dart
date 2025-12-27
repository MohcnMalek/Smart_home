import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/local_history_entry.dart';

/// A standalone service for tracking local history of device states,
/// energy consumption, and app preferences.
/// 
/// This service is designed to be non-intrusive and can be integrated
/// with existing Providers via simple injection methods.
/// 
/// Usage:
/// ```dart
/// final manager = LocalHistoryManager();
/// await manager.initialize();
/// 
/// // Log device changes
/// manager.logDeviceChange(deviceId: 'light_1', deviceType: 'light', isOn: true);
/// 
/// // Log energy values
/// manager.logEnergyValue(2.5);
/// 
/// // Log app preferences
/// manager.logAppPreference(key: 'theme', value: 'dark');
/// 
/// // Get history
/// final history = manager.getHistory();
/// final deviceHistory = manager.getHistoryByType(HistoryEntryType.deviceState);
/// ```
class LocalHistoryManager {
  static const String _storageKey = 'local_history';
  static const int _maxEntries = 1000; // Limit to prevent memory bloat
  static const int _energySamplingIntervalSeconds = 60; // Only log energy every N seconds

  SharedPreferences? _prefs;
  final List<LocalHistoryEntry> _history = [];
  DateTime? _lastEnergySampleTime;
  bool _isInitialized = false;

  /// Whether the manager has been initialized
  bool get isInitialized => _isInitialized;

  /// Returns a copy of the current history (read-only)
  List<LocalHistoryEntry> get history => List.unmodifiable(_history);

  /// Initializes the manager and loads existing history from storage
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _prefs = await SharedPreferences.getInstance();
    await _loadFromStorage();
    _isInitialized = true;
  }

  /// Logs a device state change
  /// 
  /// [deviceId] - The unique identifier of the device
  /// [deviceType] - The type of device (light, tv, ac, etc.)
  /// [isOn] - Current on/off state
  /// [level] - Optional brightness/position level (0-100)
  /// [temp] - Optional temperature setting (for AC)
  /// [mode] - Optional mode setting (for AC: cool, heat, auto, fan)
  void logDeviceChange({
    required String deviceId,
    required String deviceType,
    required bool isOn,
    double? level,
    double? temp,
    String? mode,
  }) {
    final data = <String, dynamic>{
      'deviceId': deviceId,
      'deviceType': deviceType,
      'isOn': isOn,
    };
    
    if (level != null) data['level'] = level;
    if (temp != null) data['temp'] = temp;
    if (mode != null) data['mode'] = mode;

    _addEntry(LocalHistoryEntry(
      timestamp: DateTime.now(),
      type: HistoryEntryType.deviceState,
      data: data,
    ));
  }

  /// Logs an energy consumption value
  /// 
  /// Uses sampling to avoid excessive entries (default: 1 per minute)
  /// [valueKw] - The current energy consumption in kW
  void logEnergyValue(double valueKw) {
    final now = DateTime.now();
    
    // Throttle energy logging to avoid flooding
    if (_lastEnergySampleTime != null) {
      final diff = now.difference(_lastEnergySampleTime!);
      if (diff.inSeconds < _energySamplingIntervalSeconds) {
        return;
      }
    }
    
    _lastEnergySampleTime = now;
    
    _addEntry(LocalHistoryEntry(
      timestamp: now,
      type: HistoryEntryType.energy,
      data: {'valueKw': valueKw},
    ));
  }

  /// Logs an app preference change
  /// 
  /// [key] - The preference key (e.g., 'theme', 'darkMode', 'language')
  /// [value] - The preference value
  void logAppPreference({
    required String key,
    required dynamic value,
  }) {
    _addEntry(LocalHistoryEntry(
      timestamp: DateTime.now(),
      type: HistoryEntryType.appPreference,
      data: {
        'key': key,
        'value': value,
      },
    ));
  }

  /// Gets all history entries
  List<LocalHistoryEntry> getHistory() => List.from(_history);

  /// Gets history entries filtered by type
  List<LocalHistoryEntry> getHistoryByType(String type) {
    return _history.where((e) => e.type == type).toList();
  }

  /// Gets history entries for a specific device
  List<LocalHistoryEntry> getDeviceHistory(String deviceId) {
    return _history
        .where((e) => 
            e.type == HistoryEntryType.deviceState && 
            e.data['deviceId'] == deviceId)
        .toList();
  }

  /// Gets history entries within a date range
  List<LocalHistoryEntry> getHistoryInRange(DateTime start, DateTime end) {
    return _history
        .where((e) => e.timestamp.isAfter(start) && e.timestamp.isBefore(end))
        .toList();
  }

  /// Gets history entries for today
  List<LocalHistoryEntry> getTodayHistory() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return getHistoryInRange(startOfDay, endOfDay);
  }

  /// Gets energy consumption history as a list of values
  List<double> getEnergyValues() {
    return _history
        .where((e) => e.type == HistoryEntryType.energy)
        .map((e) => (e.data['valueKw'] as num).toDouble())
        .toList();
  }

  /// Clears all history entries
  Future<void> clearHistory() async {
    _history.clear();
    await _saveToStorage();
  }

  /// Clears history entries older than the specified duration
  Future<void> clearOlderThan(Duration duration) async {
    final cutoff = DateTime.now().subtract(duration);
    _history.removeWhere((e) => e.timestamp.isBefore(cutoff));
    await _saveToStorage();
  }

  /// Exports history as JSON string
  String exportAsJson() {
    return jsonEncode(_history.map((e) => e.toJson()).toList());
  }

  /// Gets statistics summary
  Map<String, dynamic> getStatistics() {
    final deviceEntries = getHistoryByType(HistoryEntryType.deviceState);
    final energyEntries = getHistoryByType(HistoryEntryType.energy);
    final prefEntries = getHistoryByType(HistoryEntryType.appPreference);
    
    double avgEnergy = 0;
    if (energyEntries.isNotEmpty) {
      final sum = energyEntries
          .map((e) => (e.data['valueKw'] as num).toDouble())
          .reduce((a, b) => a + b);
      avgEnergy = sum / energyEntries.length;
    }

    return {
      'totalEntries': _history.length,
      'deviceStateEntries': deviceEntries.length,
      'energyEntries': energyEntries.length,
      'preferenceEntries': prefEntries.length,
      'averageEnergyKw': avgEnergy,
      'oldestEntry': _history.isNotEmpty ? _history.first.formattedTimestamp : null,
      'newestEntry': _history.isNotEmpty ? _history.last.formattedTimestamp : null,
    };
  }

  // ======================== PRIVATE METHODS ========================

  void _addEntry(LocalHistoryEntry entry) {
    _history.add(entry);
    
    // Enforce max entries limit
    while (_history.length > _maxEntries) {
      _history.removeAt(0);
    }
    
    // Save asynchronously (fire and forget for performance)
    _saveToStorage();
  }

  Future<void> _loadFromStorage() async {
    if (_prefs == null) return;
    
    final jsonString = _prefs!.getString(_storageKey);
    if (jsonString == null || jsonString.isEmpty) return;
    
    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      _history.clear();
      for (final json in jsonList) {
        _history.add(LocalHistoryEntry.fromJson(json as Map<String, dynamic>));
      }
    } catch (e) {
      // If corrupted, clear and start fresh
      _history.clear();
    }
  }

  Future<void> _saveToStorage() async {
    if (_prefs == null) return;
    
    final jsonString = jsonEncode(_history.map((e) => e.toJson()).toList());
    await _prefs!.setString(_storageKey, jsonString);
  }

  /// Call this when disposing of the manager
  void dispose() {
    // Final save before disposal
    _saveToStorage();
  }
}
