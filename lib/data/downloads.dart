import 'package:hive_flutter/hive_flutter.dart';
import 'dart:io';

class DownloadedTrack {
  final String videoId;
  final String title;
  final String artist;
  final String? albumArtPath;
  final String audioPath;
  final DateTime downloadedAt;

  DownloadedTrack({
    required this.videoId,
    required this.title,
    required this.artist,
    this.albumArtPath,
    required this.audioPath,
    required this.downloadedAt,
  });

  Map<String, dynamic> toJson() => {
    'videoId': videoId,
    'title': title,
    'artist': artist,
    'albumArtPath': albumArtPath,
    'audioPath': audioPath,
    'downloadedAt': downloadedAt.toIso8601String(),
  };

  factory DownloadedTrack.fromJson(Map<String, dynamic> json) => DownloadedTrack(
    videoId: json['videoId'],
    title: json['title'],
    artist: json['artist'],
    albumArtPath: json['albumArtPath'],
    audioPath: json['audioPath'],
    downloadedAt: DateTime.parse(json['downloadedAt']),
  );
}

class Downloads {
  static const _boxName = 'downloads';
  static late Box _box;

  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  static List<DownloadedTrack> getAll() {
    return _box.values.map((v) => DownloadedTrack.fromJson(Map<String, dynamic>.from(v))).toList()
      ..sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));
  }

  static bool isDownloaded(String videoId) {
    return _box.containsKey(videoId);
  }

  static DownloadedTrack? get(String videoId) {
    final data = _box.get(videoId);
    if (data == null) return null;
    return DownloadedTrack.fromJson(Map<String, dynamic>.from(data));
  }

  static Future<void> add(DownloadedTrack track) async {
    await _box.put(track.videoId, track.toJson());
  }

  static Future<void> remove(String videoId) async {
    final track = get(videoId);
    if (track != null) {
      try {
        final audioFile = File(track.audioPath);
        if (await audioFile.exists()) {
          await audioFile.delete();
        }
        if (track.albumArtPath != null) {
          final artFile = File(track.albumArtPath!);
          if (await artFile.exists()) {
            await artFile.delete();
          }
        }
      } catch (_) {}
    }
    await _box.delete(videoId);
  }

  static Future<void> clearAll() async {
    final tracks = getAll();
    for (final track in tracks) {
      try {
        final audioFile = File(track.audioPath);
        if (await audioFile.exists()) {
          await audioFile.delete();
        }
        if (track.albumArtPath != null) {
          final artFile = File(track.albumArtPath!);
          if (await artFile.exists()) {
            await artFile.delete();
          }
        }
      } catch (_) {}
    }
    await _box.clear();
  }
}

