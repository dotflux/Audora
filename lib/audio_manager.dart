import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import '../audora_music.dart';

class AudioManager {
  final AudoraPlayer player;
  final AudioPlayer audioPlayer = AudioPlayer();

  final ValueNotifier<MediaItem?> currentTrackNotifier = ValueNotifier(null);
  final ValueNotifier<bool> isFetchingNotifier = ValueNotifier(false);

  MediaItem? currentTrack;
  String? _currentPlayingVideoId;

  final Map<String, String> _urlCache = {};

  AudioManager(this.player);

  Future<void> playTrack(Track track) async {
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
      await audioPlayer.load();
      isFetchingNotifier.value = false;
      await audioPlayer.play();
    } catch (e, st) {
      if (_currentPlayingVideoId != requestedVideoId) return;
      print('[ERROR] Playback failed: $e');
      print(st);

      try {
        final audioData = await player.getAudioFromServer(requestedVideoId);
        if (_currentPlayingVideoId != requestedVideoId) return;
        if (audioData == null || audioData['url'] == null) return;
        final newUrl = audioData['url'];
        _urlCache[requestedVideoId] = newUrl;

        await audioPlayer.setAudioSource(AudioSource.uri(Uri.parse(newUrl)));
        if (_currentPlayingVideoId != requestedVideoId) return;
        await audioPlayer.load();
        await audioPlayer.play();
        print('[INFO] Retried with fresh URL for ${track.title}');
      } catch (e2, st2) {
        if (_currentPlayingVideoId != requestedVideoId) return;
        print('[ERROR] Retry failed: $e2');
        print(st2);
      }
    } finally {
      if (_currentPlayingVideoId == requestedVideoId) {
        isFetchingNotifier.value = false;
      }
    }
  }

  void skipTrack() {
    audioPlayer.stop();
  }
}
