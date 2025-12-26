import 'package:flutter/foundation.dart';
import 'home_provider.dart';
import '../models/room.dart';

class RoomProvider extends ChangeNotifier {
  HomeProvider? _home;

  void attach(HomeProvider home) {
    _home = home;
  }

  Room? getRoomById(String roomId) {
    final home = _home;
    if (home == null) return null;
    for (final r in home.rooms) {
      if (r.id == roomId) return r;
    }
    return null;
  }

  int activeInRoom(String roomId) {
    final room = getRoomById(roomId);
    if (room == null) return 0;
    return room.devices.where((d) => d.isOn).length;
  }
}
