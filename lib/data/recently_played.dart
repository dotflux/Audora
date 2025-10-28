import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../audora_music.dart';

class RecentlyPlayed {
  static const _storageKey = 'recentlyPlayed';
  static final List<Track> _tracks = [];
  static final StreamController<void> _onChangeController =
      StreamController.broadcast();

  static Stream<void> get onChange => _onChangeController.stream;

  static Future<void> _ensureLoaded() async {
    if (_tracks.isNotEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);
    if (jsonString != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        _tracks
          ..clear()
          ..addAll(jsonList.map((e) => Track.fromJson(e)));
      } catch (e) {
        print('[RecentlyPlayed] Failed to decode: $e');
      }
    }
  }

  static Future<void> addTrack(Track track) async {
    await _ensureLoaded();

    _tracks.removeWhere((t) => t.videoId == track.videoId);
    _tracks.insert(0, track);

    if (_tracks.length > 25) _tracks.removeRange(25, _tracks.length);

    await _saveToStorage();

    _onChangeController.add(null);
  }

  static Future<List<Track>> getTracks() async {
    await _ensureLoaded();
    return List.unmodifiable(_tracks);
  }

  static Future<void> clear() async {
    _tracks.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    _onChangeController.add(null);
  }

  static Future<void> _saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _tracks.map((t) => t.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(jsonList));
  }
}
