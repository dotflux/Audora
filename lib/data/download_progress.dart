import 'package:hive_flutter/hive_flutter.dart';
import '../utils/log.dart';

class DownloadProgress {
  final String videoId;
  final int progress;
  final String status;
  final String? title;
  final String? artist;

  DownloadProgress({
    required this.videoId,
    required this.progress,
    required this.status,
    this.title,
    this.artist,
  });

  Map<String, dynamic> toJson() => {
    'videoId': videoId,
    'progress': progress,
    'status': status,
    'title': title,
    'artist': artist,
  };

  factory DownloadProgress.fromJson(Map<String, dynamic> json) =>
      DownloadProgress(
        videoId: json['videoId'],
        progress: json['progress'],
        status: json['status'],
        title: json['title'],
        artist: json['artist'],
      );
}

class DownloadProgressTracker {
  static const _boxName = 'download_progress';
  static late Box _box;

  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  static void update(
    String videoId,
    int progress,
    String status, {
    String? title,
    String? artist,
  }) {
    log.d('[DL][PROGRESS] $videoId -> $progress% ($status)');
    final existing = get(videoId);
    _box.put(
      videoId,
      DownloadProgress(
        videoId: videoId,
        progress: progress,
        status: status,
        title: title ?? existing?.title,
        artist: artist ?? existing?.artist,
      ).toJson(),
    );
  }

  static DownloadProgress? get(String videoId) {
    final data = _box.get(videoId);
    if (data == null) return null;
    return DownloadProgress.fromJson(Map<String, dynamic>.from(data));
  }

  static void remove(String videoId) {
    log.d('[DL][PROGRESS] removed $videoId');
    _box.delete(videoId);
  }

  static Map<String, DownloadProgress> getAll() {
    log.d('[DL][PROGRESS] getAll count=${_box.values.length}');
    return Map.fromEntries(
      _box.values.map((v) {
        final progress = DownloadProgress.fromJson(
          Map<String, dynamic>.from(v),
        );
        return MapEntry(progress.videoId, progress);
      }),
    );
  }
}
