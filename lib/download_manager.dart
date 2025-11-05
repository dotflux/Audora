import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'data/download_progress.dart';
import 'data/downloads.dart';
import 'utils/log.dart';

class _DownloadTask {
  final String videoId;
  final String title;
  final String artist;
  final Uri audioUri;
  final Uri? artUri;

  _DownloadTask({
    required this.videoId,
    required this.title,
    required this.artist,
    required this.audioUri,
    required this.artUri,
  });
}

class _ActiveDownload {
  final http.Client client;
  final StreamSubscription<List<int>> subscription;
  final IOSink sink;
  final String tempPath;

  _ActiveDownload({
    required this.client,
    required this.subscription,
    required this.sink,
    required this.tempPath,
  });
}

class DownloadManager {
  static final DownloadManager instance = DownloadManager._();
  DownloadManager._();

  final int _maxConcurrent = 4;
  final Queue<_DownloadTask> _queue = Queue();
  final Map<String, _ActiveDownload> _active = {};
  bool _isProcessingQueue = false;

  Future<void> enqueue({
    required String videoId,
    required String title,
    required String artist,
    required Uri audioUri,
    Uri? artUri,
  }) async {
    if (Downloads.isDownloaded(videoId)) return;

    _queue.add(
      _DownloadTask(
        videoId: videoId,
        title: title,
        artist: artist,
        audioUri: audioUri,
        artUri: artUri,
      ),
    );

    DownloadProgressTracker.update(
      videoId,
      0,
      'Queued...',
      title: title,
      artist: artist,
    );
    _pumpQueue();
  }

  void _pumpQueue() {
    if (_isProcessingQueue) return;
    _isProcessingQueue = true;
    scheduleMicrotask(() async {
      try {
        while (_active.length < _maxConcurrent && _queue.isNotEmpty) {
          final task = _queue.removeFirst();
          if (Downloads.isDownloaded(task.videoId)) {
            continue;
          }
          _startTask(task);
        }
      } finally {
        _isProcessingQueue = false;
      }
    });
  }

  Future<void> _startTask(_DownloadTask task, {int attempt = 1}) async {
    final videoId = task.videoId;
    final title = task.title;
    final artist = task.artist;
    final audioUri = task.audioUri;
    final artUri = task.artUri;

    try {
      DownloadProgressTracker.update(
        videoId,
        0,
        'Preparing download...',
        title: title,
        artist: artist,
      );

      final appDir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${appDir.path}/downloads');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      final tempPath = '${downloadsDir.path}/$videoId.tmp';
      final finalAudioPath = '${downloadsDir.path}/$videoId.m4a';
      final file = File(tempPath);
      if (await file.exists()) {
        await file.delete();
      }
      final sink = file.openWrite();

      DownloadProgressTracker.update(
        videoId,
        10,
        'Downloading audio...',
        title: title,
        artist: artist,
      );

      final client = http.Client();
      final request = http.Request('GET', audioUri);
      final response = await client.send(request);
      if (response.statusCode != 200) {
        await sink.close();
        await file.delete().catchError((_) => file);
        client.close();
        throw Exception('Failed to download audio (${response.statusCode})');
      }

      final contentLength = response.contentLength ?? 0;
      int received = 0;
      int lastReported = 10;
      final sub = response.stream
          .timeout(
            const Duration(seconds: 20),
            onTimeout: (eventSink) {
              eventSink.addError(TimeoutException('Audio download stalled'));
            },
          )
          .listen(
            (chunk) {
              sink.add(chunk);
              received += chunk.length;
              if (contentLength > 0) {
                final pct = (received * 100 ~/ contentLength).clamp(10, 89);
                if (pct >= lastReported + 2) {
                  lastReported = pct;
                  DownloadProgressTracker.update(
                    videoId,
                    pct,
                    'Downloading audio...',
                    title: title,
                    artist: artist,
                  );
                }
              }
            },
            onError: (e) async {
              await sink.close();
              await file.delete().catchError((_) => file);
              client.close();
              _active.remove(videoId);
              log.d('[DL][ERROR] $videoId -> $e');
              if (attempt < 2) {
                DownloadProgressTracker.update(
                  videoId,
                  lastReported,
                  'Retrying...',
                  title: title,
                  artist: artist,
                );

                _queue.addFirst(task);
                _pumpQueue();
              } else {
                DownloadProgressTracker.remove(videoId);
                _pumpQueue();
              }
            },
            onDone: () async {
              await sink.close();

              try {
                await file.rename(finalAudioPath);
              } catch (_) {
                final finalFile = File(finalAudioPath);
                await finalFile.writeAsBytes(
                  await File(tempPath).readAsBytes(),
                );
                await File(tempPath).delete().catchError((_) => File(tempPath));
              }

              String? albumArtPath;
              if (artUri != null) {
                DownloadProgressTracker.update(
                  videoId,
                  90,
                  'Downloading album art...',
                  title: title,
                  artist: artist,
                );
                try {
                  final artRes = await http
                      .get(artUri)
                      .timeout(const Duration(seconds: 12));
                  if (artRes.statusCode == 200) {
                    albumArtPath = '${downloadsDir.path}/$videoId\_art.jpg';
                    final artFile = File(albumArtPath);
                    await artFile.writeAsBytes(artRes.bodyBytes);
                  }
                } catch (e) {
                  log.d('[DL][ART][WARN] $videoId -> $e');
                }
              }

              DownloadProgressTracker.update(
                videoId,
                100,
                'Saving...',
                title: title,
                artist: artist,
              );

              await Downloads.add(
                DownloadedTrack(
                  videoId: videoId,
                  title: title,
                  artist: artist,
                  albumArtPath: albumArtPath,
                  audioPath: finalAudioPath,
                  downloadedAt: DateTime.now(),
                ),
              );
              DownloadProgressTracker.remove(videoId);

              client.close();
              _active.remove(videoId);
              log.d('[DL] Download completed and recorded for $videoId');
              _pumpQueue();
            },
            cancelOnError: true,
          );

      _active[videoId] = _ActiveDownload(
        client: client,
        subscription: sub,
        sink: sink,
        tempPath: tempPath,
      );
    } catch (e) {
      log.d('[DL][ERROR] $videoId -> $e');
      DownloadProgressTracker.remove(videoId);
      _active.remove(videoId);
      _pumpQueue();
    }
  }

  Future<void> cancel(String videoId) async {
    final active = _active.remove(videoId);
    if (active != null) {
      try {
        await active.subscription.cancel();
      } catch (_) {}
      try {
        await active.sink.close();
      } catch (_) {}
      try {
        active.client.close();
      } catch (_) {}
      try {
        final f = File(active.tempPath);
        if (await f.exists()) {
          await f.delete();
        }
      } catch (_) {}
    } else {
      _queue.removeWhere((t) => t.videoId == videoId);
    }
    DownloadProgressTracker.remove(videoId);
    log.d('[DL] Cancelled $videoId');
    _pumpQueue();
  }
}
