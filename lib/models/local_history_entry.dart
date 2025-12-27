/// Model class representing a single entry in the local history log.
/// 
/// Tracks device state changes, energy consumption values, and app preferences
/// with precise timestamps.
class LocalHistoryEntry {
  /// The timestamp when this entry was recorded
  final DateTime timestamp;
  
  /// Type of history entry: 'device_state', 'energy', or 'app_preference'
  final String type;
  
  /// Additional data specific to the entry type
  /// 
  /// For device_state: {deviceId, deviceType, isOn, level?, temp?, mode?}
  /// For energy: {value (kW)}
  /// For app_preference: {key, value}
  final Map<String, dynamic> data;

  const LocalHistoryEntry({
    required this.timestamp,
    required this.type,
    required this.data,
  });

  /// Creates a history entry from JSON data
  factory LocalHistoryEntry.fromJson(Map<String, dynamic> json) {
    return LocalHistoryEntry(
      timestamp: DateTime.parse(json['timestamp'] as String),
      type: json['type'] as String,
      data: Map<String, dynamic>.from(json['data'] as Map),
    );
  }

  /// Converts this entry to JSON for storage
  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'type': type,
    'data': data,
  };

  /// Formatted day string (YYYY-MM-DD)
  String get day => '${timestamp.year}-${_pad(timestamp.month)}-${_pad(timestamp.day)}';

  /// Formatted time string (HH:MM)
  String get time => '${_pad(timestamp.hour)}:${_pad(timestamp.minute)}';

  /// Full formatted timestamp (YYYY-MM-DD HH:MM:SS)
  String get formattedTimestamp => 
    '$day ${_pad(timestamp.hour)}:${_pad(timestamp.minute)}:${_pad(timestamp.second)}';

  String _pad(int value) => value.toString().padLeft(2, '0');

  @override
  String toString() => 'LocalHistoryEntry(type: $type, timestamp: $formattedTimestamp, data: $data)';
}

/// Type constants for history entries
abstract class HistoryEntryType {
  static const String deviceState = 'device_state';
  static const String energy = 'energy';
  static const String appPreference = 'app_preference';
}
