import 'package:hive_flutter/hive_flutter.dart';

class TrackLoopAfter {
  static const _boxName = 'trackLoopAfter';
  static late Box _box;

  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  static Future<void> setLoopAfter(String videoId, int? positionMs) async {
    if (positionMs == null) {
      await _box.delete(videoId);
    } else {
      await _box.put(videoId, positionMs);
    }
  }

  static int? getLoopAfter(String videoId) {
    final value = _box.get(videoId);
    if (value == null) return null;
    return value is int ? value : null;
  }

  static bool hasLoopAfter(String videoId) {
    return _box.containsKey(videoId);
  }

  static Future<void> resetLoopAfter(String videoId) async {
    await _box.delete(videoId);
  }
}
