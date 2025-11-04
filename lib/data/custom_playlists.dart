import 'package:hive_flutter/hive_flutter.dart';
import '../audora_music.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../utils/log.dart';

class CustomPlaylists {
  static const _boxName = 'customPlaylists';
  static late Box _box;

  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  static List<String> getPlaylistNames() {
    return _box.keys.cast<String>().toList();
  }

  static int getTrackCount(String playlistName) {
    if (!_box.containsKey(playlistName)) return 0;
    final raw = _box.get(playlistName);
    if (raw == null) return 0;
    final data = Map<String, dynamic>.from(raw);
    final tracks = data['tracks'] as List?;
    return tracks?.length ?? 0;
  }

  static Future<bool> createPlaylist(String name, {String? coverPath}) async {
    if (_box.containsKey(name)) return false;
    await _box.put(name, {'cover': coverPath, 'tracks': []});
    return true;
  }

  static Future<void> deletePlaylist(String name) async {
    await _box.delete(name);
  }

  static Future<void> renamePlaylist(String oldName, String newName) async {
    if (!_box.containsKey(oldName)) return;
    if (_box.containsKey(newName)) throw Exception('Name already exists');
    final data = _box.get(oldName);
    await _box.put(newName, data);
    await _box.delete(oldName);
  }

  static Future<void> setCoverImage(
    String playlistName,
    String? coverPath,
  ) async {
    if (!_box.containsKey(playlistName)) return;

    final data = Map<String, dynamic>.from(_box.get(playlistName));

    final oldCoverPath = data['cover'];
    if (oldCoverPath != null) {
      final oldFile = File(oldCoverPath);
      if (await oldFile.exists()) await oldFile.delete();
    }

    if (coverPath != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final newPath = '${appDir.path}/cover_$playlistName.jpg';
      final newFile = await File(coverPath).copy(newPath);
      data['cover'] = newFile.path;
    } else {
      data['cover'] = null;
    }

    await _box.put(playlistName, data);
    log.d("COVER: ${data['cover']}");
  }

  static String? getCoverImage(String playlistName) {
    if (!_box.containsKey(playlistName)) return null;
    final data = Map<String, dynamic>.from(_box.get(playlistName));
    return data['cover'];
  }

  static Future<bool> addTrack(String playlistName, Track track) async {
    if (!_box.containsKey(playlistName)) return false;
    final data = Map<String, dynamic>.from(_box.get(playlistName));
    final List<Map<String, dynamic>> existingJson = (data['tracks'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        <Map<String, dynamic>>[];

    if (existingJson.any((t) => t['videoId'] == track.videoId)) return false;

    existingJson.add(track.toJson());
    data['tracks'] = existingJson;
    await _box.put(playlistName, data);
    return true;
  }

  static Future<void> removeTrack(String playlistName, String videoId) async {
    if (!_box.containsKey(playlistName)) return;
    final data = Map<String, dynamic>.from(_box.get(playlistName));
    final List<Map<String, dynamic>> existingJson = (data['tracks'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        <Map<String, dynamic>>[];
    existingJson.removeWhere((t) => t['videoId'] == videoId);
    data['tracks'] = existingJson;
    await _box.put(playlistName, data);
  }

  static List<Track> getTracks(String playlistName) {
    if (!_box.containsKey(playlistName)) return [];

    final raw = _box.get(playlistName);
    if (raw == null) return [];

    final data = Map<String, dynamic>.from(raw);

    final tracks = (data['tracks'] as List?)
        ?.map((e) => Track.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    return tracks ?? [];
  }

  static Future<void> reorderTracks(
    String playlistName,
    int oldIndex,
    int newIndex,
  ) async {
    if (!_box.containsKey(playlistName)) return;
    final data = Map<String, dynamic>.from(_box.get(playlistName));
    final List existingJson = List<Map<String, dynamic>>.from(data['tracks']);

    if (newIndex > oldIndex) newIndex -= 1;
    final track = existingJson.removeAt(oldIndex);
    existingJson.insert(newIndex, track);

    data['tracks'] = existingJson;
    await _box.put(playlistName, data);
  }

  static Future<void> clearAll() async => await _box.clear();

  static Future<void> setTracks(String playlistName, List<Track> tracks) async {
    if (!_box.containsKey(playlistName)) return;
    final data = Map<String, dynamic>.from(_box.get(playlistName));
    data['tracks'] = tracks.map((t) => t.toJson()).toList();
    await _box.put(playlistName, data);
  }
}
