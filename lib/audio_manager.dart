import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import '../audora_music.dart';
import './utils/log.dart';
import 'dart:async';
import '/data/recently_played.dart';

class AudioManager {
  final AudoraPlayer player;
  final AudioPlayer audioPlayer = AudioPlayer();

  final ValueNotifier<MediaItem?> currentTrackNotifier = ValueNotifier(null);
  final ValueNotifier<bool> isFetchingNotifier = ValueNotifier(false);

  MediaItem? currentTrack;
  String? _currentPlayingVideoId;
  bool _isHandlingCompletion = false;

  final Map<String, String> _urlCache = {};

  List<Track> _queue = [];
  int _currentIndex = -1;

  AudioManager(this.player) {
    audioPlayer.playerStateStream.listen((state) {
      log.d(
        "PLAYER STATE: ${state.processingState}, playing: ${state.playing}",
      );
    });

    audioPlayer.positionStream.listen((pos) async {
      final duration = audioPlayer.duration;
      if (duration != null &&
          pos >= duration - const Duration(milliseconds: 500)) {
        log.d("Detected natural end of track!");
        _handleTrackComplete();
      }
    });
  }

  Future<void> playTrack(Track track, {List<Track>? queue}) async {
    if (queue != null) {
      _queue = queue;
      _currentIndex = queue.indexWhere((t) => t.videoId == track.videoId);
      log.d(
        "Uh queue is not null and videoID $track.videoId and currentIndex is $_currentIndex",
      );
    }

    final requestedVideoId = track.videoId;
    _currentPlayingVideoId = requestedVideoId;

    currentTrack = MediaItem(
      id: track.videoId,
      album: "YouTube Music",
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
        final audioData = await player.getAudioFromServer(requestedVideoId);
        if (_currentPlayingVideoId != requestedVideoId) return;
        if (audioData == null || audioData['url'] == null) return;
        url = audioData['url'];
        _urlCache[requestedVideoId] = url;
      }

      await audioPlayer.setAudioSource(AudioSource.uri(Uri.parse(url)));
      if (_currentPlayingVideoId != requestedVideoId) return;

      isFetchingNotifier.value = false;
      audioPlayer.play();

      unawaited(RecentlyPlayed.addTrack(track));
    } catch (e, st) {
      print('[ERROR] Playback failed: $e');
      print(st);
    } finally {
      if (_currentPlayingVideoId == requestedVideoId) {
        isFetchingNotifier.value = false;
      }
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
      return;
    }

    log.i('Handle track complete was entered');
    int nextIndex = _currentIndex + 1;

    if (nextIndex >= _queue.length) {
      log.i('End of queue reached. Wrapping to first track.');
      nextIndex = 0;
    }

    final nextTrack = _queue[nextIndex];
    await Future.delayed(const Duration(milliseconds: 600));
    log.i('Auto-playing next track: ${nextTrack.title}');
    _currentIndex = nextIndex;
    await playTrack(nextTrack);

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
    await playTrack(next);
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
    await playTrack(prev);
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
}
