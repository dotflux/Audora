import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../audora_music.dart';

class CustomPlaylists {
  static const _boxName = 'customPlaylists';
  static late Box _box;

  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  static List<String> getPlaylistNames() {
    return _box.keys.cast<String>().toList();
  }

  static Future<bool> createPlaylist(String name) async {
    if (_box.containsKey(name)) return false;
    await _box.put(name, []);
    return true;
  }

  static Future<void> deletePlaylist(String name) async {
    await _box.delete(name);
  }

  static Future<void> renamePlaylist(String oldName, String newName) async {
    if (!_box.containsKey(oldName)) return;
    if (_box.containsKey(newName)) throw Exception('Name already exists');
    final tracks = _box.get(oldName);
    await _box.put(newName, tracks);
    await _box.delete(oldName);
  }

  static Future<bool> addTrack(String playlistName, Track track) async {
    if (!_box.containsKey(playlistName)) return false;
    final List existingJson = _box.get(playlistName).cast<Map>();

    if (existingJson.any((t) => t['videoId'] == track.videoId)) {
      return false;
    }

    existingJson.add(track.toJson());
    await _box.put(playlistName, existingJson);
    return true;
  }

  static Future<void> removeTrack(String playlistName, String videoId) async {
    if (!_box.containsKey(playlistName)) return;
    final List existingJson = _box.get(playlistName).cast<Map>();
    existingJson.removeWhere((t) => t['videoId'] == videoId);
    await _box.put(playlistName, existingJson);
  }

  static List<Track> getTracks(String playlistName) {
    if (!_box.containsKey(playlistName)) return [];
    final List data = _box.get(playlistName);
    return data
        .map((e) => Track.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<void> clearAll() async {
    await _box.clear();
  }
}
