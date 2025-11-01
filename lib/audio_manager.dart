import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import '../audora_music.dart';
import './utils/log.dart';
import 'dart:async';
import '/data/recently_played.dart';
import '/data/track_best_parts.dart';
import 'audora_notification.dart';

class AudioManager {
  final AudoraPlayer player;
  final AudioPlayer audioPlayer = AudioPlayer();
  late final AudoraSearch _search;

  final ValueNotifier<MediaItem?> currentTrackNotifier = ValueNotifier(null);
  final ValueNotifier<bool> isFetchingNotifier = ValueNotifier(false);
  final ValueNotifier<List<Track>> queueNotifier = ValueNotifier([]);

  MediaItem? currentTrack;
  String? _currentPlayingVideoId;
  bool _isHandlingCompletion = false;

  final Map<String, String> _urlCache = {};

  List<Track> _queue = [];
  int _currentIndex = -1;

  LoopMode _loopMode = LoopMode.off;
  final ValueNotifier<LoopMode> loopModeNotifier = ValueNotifier(LoopMode.off);

  int _lastNotificationUpdateMs = 0;
  static const int _notificationThrottleMs = 800;
  bool _isSeeking = false;

  AudioManager(this.player) {
    _search = AudoraSearch(player.client);
    AudoraNotification.init();
    AudoraNotification.onAction =
        (String action, {Map<String, dynamic>? extras}) async {
          log.d('Notification action received: $action');
          try {
            switch (action) {
              case 'com.example.audora.ACTION_PREV':
                await skipToPrevious();
                break;
              case 'com.example.audora.ACTION_TOGGLE':
                if (audioPlayer.playing) {
                  await audioPlayer.pause();
                } else {
                  await audioPlayer.play();
                }
                break;
              case 'com.example.audora.ACTION_NEXT':
                await skipToNext();
                break;
              case 'com.example.audora.ACTION_BEST_PART':
                await seekToBestPart();
                break;
              case 'com.example.audora.ACTION_SEEK':
                final positionMs = extras?['positionMs'] as int?;
                if (positionMs != null && audioPlayer.duration != null) {
                  final target = Duration(milliseconds: positionMs);
                  if (target < audioPlayer.duration!) {
                    _isSeeking = true;
                    await audioPlayer.seek(target);

                    if (currentTrack != null) {
                      final durationMs = audioPlayer.duration?.inMilliseconds;
                      await AudoraNotification.show(
                        title: currentTrack!.title,
                        artist: currentTrack!.artist ?? 'Unknown Artist',
                        artworkUrl: currentTrack!.artUri?.toString(),
                        isPlaying: audioPlayer.playing,
                        positionMs: positionMs,
                        durationMs: durationMs,
                        hasBestPart: hasBestPart(),
                      );
                      _lastNotificationUpdateMs =
                          DateTime.now().millisecondsSinceEpoch;
                    }

                    Future.delayed(const Duration(milliseconds: 500), () {
                      _isSeeking = false;
                    });
                  }
                }
                break;
              default:
                log.d('Unknown notification action: $action');
            }
          } catch (e, st) {
            log.d('[ERROR] handling notification action: $e');
            log.d(st);
          }
        };

    audioPlayer.playerStateStream.listen((state) async {
      log.d(
        "PLAYER STATE: ${state.processingState}, playing: ${state.playing}",
      );

      if (currentTrack != null) {
        final durationMs = audioPlayer.duration?.inMilliseconds;
        final positionMs = audioPlayer.position.inMilliseconds;

        try {
          await AudoraNotification.show(
            title: currentTrack!.title,
            artist: currentTrack!.artist ?? 'Unknown Artist',
            artworkUrl: currentTrack!.artUri?.toString(),
            isPlaying: state.playing,
            positionMs: positionMs,
            durationMs: durationMs,
            hasBestPart: hasBestPart(),
          );

          _lastNotificationUpdateMs = DateTime.now().millisecondsSinceEpoch;
        } catch (e, st) {
          log.d(
            '[ERROR] AudoraNotification.show failed on playerStateStream: $e',
          );
          log.d(st);
        }
      }

      if (state.processingState == ProcessingState.completed ||
          state.processingState == ProcessingState.idle) {
        try {
          await AudoraNotification.hide();
        } catch (e, st) {
          log.d('[ERROR] AudoraNotification.hide failed: $e');
          log.d(st);
        }
      }
    });

    audioPlayer.positionStream.listen((pos) async {
      final duration = audioPlayer.duration;

      if (duration != null &&
          pos >= duration - const Duration(milliseconds: 500)) {
        log.d("Detected natural end of track!");
        _handleTrackComplete();
      }

      if (_isSeeking) return;

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (nowMs - _lastNotificationUpdateMs < _notificationThrottleMs) {
        return;
      }
      _lastNotificationUpdateMs = nowMs;

      if (currentTrack != null) {
        try {
          await AudoraNotification.show(
            title: currentTrack!.title,
            artist: currentTrack!.artist ?? 'Unknown Artist',
            artworkUrl: currentTrack!.artUri?.toString(),
            isPlaying: audioPlayer.playing,
            positionMs: pos.inMilliseconds,
            durationMs: duration?.inMilliseconds,
            hasBestPart: hasBestPart(),
          );
        } catch (e, st) {
          log.d('[ERROR] AudoraNotification.show failed on positionStream: $e');
          log.d(st);
        }
      }
    });
  }

  Future<void> playTrack(
    Track track, {
    List<Track>? queue,
    bool fetchRelated = false,
    bool fromQueue = false,
  }) async {
    final bool shouldFetchRelated = fetchRelated && queue == null && !fromQueue;

    if (queue != null) {
      _queue = queue;
      _currentIndex = queue.indexWhere((t) => t.videoId == track.videoId);
      queueNotifier.value = List.from(_queue);
      log.d(
        "Queue not null — playing track ${track.videoId}, index $_currentIndex",
      );
    } else if (!shouldFetchRelated && !fromQueue) {
      _queue = [track];
      _currentIndex = 0;
      queueNotifier.value = List.from(_queue);
    } else if (!fromQueue) {
      _queue = [track];
      _currentIndex = 0;
      queueNotifier.value = List.from(_queue);
    }

    final requestedVideoId = track.videoId;
    _currentPlayingVideoId = requestedVideoId;

    currentTrack = MediaItem(
      id: track.videoId,
      album: "Audora",
      title: track.title,
      artist: track.artist,
      artUri: track.thumbnail != null ? Uri.parse(track.thumbnail!) : null,
    );
    currentTrackNotifier.value = currentTrack;
    isFetchingNotifier.value = true;

    try {
      await audioPlayer.stop();

      if (_currentPlayingVideoId != requestedVideoId) return;

      String url;

      if (_urlCache.containsKey(requestedVideoId)) {
        url = _urlCache[requestedVideoId]!;
      } else {
        final fetched = await player.getAudioUrlExplode(requestedVideoId);
        if (_currentPlayingVideoId != requestedVideoId) return;
        if (fetched == null) return;
        url = fetched;
        _urlCache[requestedVideoId] = url;
      }

      await audioPlayer.setAudioSource(AudioSource.uri(Uri.parse(url)));
      if (_currentPlayingVideoId != requestedVideoId) return;

      isFetchingNotifier.value = false;
      audioPlayer.play();

      final durationMs = audioPlayer.duration?.inMilliseconds;
      final positionMs = audioPlayer.position.inMilliseconds;

      try {
        await AudoraNotification.show(
          title: track.title,
          artist: track.artist,
          artworkUrl: track.thumbnail,
          isPlaying: true,
          positionMs: positionMs,
          durationMs: durationMs,
          hasBestPart: hasBestPart(),
        );
        _lastNotificationUpdateMs = DateTime.now().millisecondsSinceEpoch;
      } catch (e, st) {
        log.d('[ERROR] AudoraNotification.show failed in playTrack: $e');
        log.d(st);
      }

      unawaited(RecentlyPlayed.addTrack(track));

      if (shouldFetchRelated) {
        unawaited(_fetchRelatedSongsInBackground(track));
      }
    } catch (e, st) {
      log.d('[ERROR] Playback failed: $e');
      log.d(st);
      try {
        await AudoraNotification.hide();
      } catch (_) {}
    } finally {
      if (_currentPlayingVideoId == requestedVideoId) {
        isFetchingNotifier.value = false;
      }
    }
  }

  Future<void> _fetchRelatedSongsInBackground(Track track) async {
    try {
      log.d('🎵 [Background] Fetching related songs for: ${track.title}');
      final relatedSongs = await _search.getRelatedSongs(track.videoId);

      if (relatedSongs.isNotEmpty && _currentPlayingVideoId == track.videoId) {
        final filteredSongs = relatedSongs
            .where((song) => song.videoId != track.videoId)
            .toList();

        _queue = [track, ...filteredSongs];
        queueNotifier.value = List.from(_queue);
        log.d(
          '✅ [Background] Added ${filteredSongs.length} related songs to queue',
        );
      } else {
        log.d('⚠️ [Background] No related songs found or track changed');
      }
    } catch (e, st) {
      log.d('❌ [Background] Failed to fetch related songs: $e');
      log.d(st);
    }
  }

  void updateQueue(List<Track> newQueue) {
    final currentTrackId = _queue.isEmpty || _currentIndex < 0
        ? null
        : _queue[_currentIndex].videoId;

    _queue = List.from(newQueue);

    if (currentTrackId != null) {
      final newIndex = _queue.indexWhere((t) => t.videoId == currentTrackId);
      _currentIndex = newIndex != -1
          ? newIndex
          : (_currentIndex >= _queue.length
                ? _queue.length - 1
                : _currentIndex);
    } else {
      _currentIndex = _queue.isEmpty ? -1 : 0;
    }
  }

  void _handleTrackComplete() async {
    if (_isHandlingCompletion) return;
    _isHandlingCompletion = true;

    if (_queue.isEmpty || _currentIndex < 0) {
      log.i('RETURNED FROM TRACK COMPLETE');
      _isHandlingCompletion = false;
      try {
        await AudoraNotification.hide();
      } catch (_) {}
      return;
    }

    log.i('Handle track complete entered');

    if (_loopMode != LoopMode.off && _currentPlayingVideoId != null) {
      final bestPartMs = TrackBestParts.getBestPart(_currentPlayingVideoId!);
      if (bestPartMs != null) {
        log.i('Loop enabled with best part, seeking to best part');
        await audioPlayer.seek(Duration(milliseconds: bestPartMs));
        await audioPlayer.play();
        _isHandlingCompletion = false;
        return;
      }
    }

    if (_loopMode == LoopMode.one) {
      log.i('Loop one: replaying current track');
      await audioPlayer.seek(Duration.zero);
      await audioPlayer.play();
      _isHandlingCompletion = false;
      return;
    }

    int nextIndex = _currentIndex + 1;

    if (nextIndex >= _queue.length) {
      if (_loopMode == LoopMode.all) {
        log.i('Loop all: wrapping to first track.');
        nextIndex = 0;
      } else {
        log.i('End of queue reached.');
        _isHandlingCompletion = false;
        try {
          await AudoraNotification.hide();
        } catch (_) {}
        return;
      }
    }

    final nextTrack = _queue[nextIndex];
    await Future.delayed(const Duration(milliseconds: 600));
    log.i('Auto-playing next track: ${nextTrack.title}');
    _currentIndex = nextIndex;
    await playTrack(nextTrack, fromQueue: true);

    _isHandlingCompletion = false;
  }

  Future<void> _nextTrack() async {
    if (_queue.isEmpty) return;

    final nextIndex = _currentIndex + 1;
    if (nextIndex >= _queue.length) {
      log.i('Next track requested but end of queue reached.');
      return;
    }

    _currentIndex = nextIndex;
    final next = _queue[nextIndex];
    log.i('Playing next track: ${next.title}');
    await playTrack(next, fromQueue: true);
  }

  Future<void> _previousTrack() async {
    if (_queue.isEmpty) return;

    final prevIndex = _currentIndex - 1;
    if (prevIndex < 0) {
      log.i('Previous track requested but start of queue reached.');
      return;
    }

    _currentIndex = prevIndex;
    final prev = _queue[prevIndex];
    log.i('Playing previous track: ${prev.title}');
    await playTrack(prev, fromQueue: true);
  }

  Future<void> skipToNext() async {
    await audioPlayer.stop();
    await _nextTrack();
  }

  Future<void> skipToPrevious() async {
    await audioPlayer.stop();
    await _previousTrack();
  }

  void skipTrack() {
    audioPlayer.stop();
    _handleTrackComplete();
  }

  void setLoopMode(LoopMode mode) {
    _loopMode = mode;
    loopModeNotifier.value = mode;
    audioPlayer.setLoopMode(mode);
  }

  LoopMode getLoopMode() => _loopMode;

  Future<void> seekToBestPart() async {
    if (_currentPlayingVideoId == null) return;
    final bestPartMs = TrackBestParts.getBestPart(_currentPlayingVideoId!);
    if (bestPartMs != null && audioPlayer.duration != null) {
      final target = Duration(milliseconds: bestPartMs);
      if (target < audioPlayer.duration!) {
        await audioPlayer.seek(target);
      }
    }
  }

  bool hasBestPart() {
    if (_currentPlayingVideoId == null) return false;
    return TrackBestParts.hasBestPart(_currentPlayingVideoId!);
  }

  List<Track> get queue => List.unmodifiable(_queue);
  int get currentIndex => _currentIndex;
  void setCurrentIndex(int index) {
    if (index >= 0 && index < _queue.length) {
      _currentIndex = index;
      playTrack(_queue[index], fromQueue: true);
    }
  }
}
