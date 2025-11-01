import 'package:hive_flutter/hive_flutter.dart';
import '../utils/log.dart';

class TrackBestParts {
  static const _boxName = 'trackBestParts';
  static late Box _box;

  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  static Future<void> setBestPart(String videoId, int? positionMs) async {
    if (positionMs == null) {
      await _box.delete(videoId);
    } else {
      await _box.put(videoId, positionMs);
    }
  }

  static int? getBestPart(String videoId) {
    final value = _box.get(videoId);
    if (value == null) return null;
    return value is int ? value : null;
  }

  static bool hasBestPart(String videoId) {
    return _box.containsKey(videoId);
  }

  static Future<void> resetBestPart(String videoId) async {
    await _box.delete(videoId);
  }
}
