import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'ytm/player.dart';
import 'ytm/track.dart';

class MusicAudioHandler extends BaseAudioHandler {
  final AudoraPlayer audoraPlayer;
  final AudioPlayer _player = AudioPlayer();

  MusicAudioHandler(this.audoraPlayer);

  @override
  Future<void> playMediaItem(MediaItem mediaItem) async {
    final track = Track(
      title: mediaItem.title,
      artist: mediaItem.artist ?? '',
      videoId: mediaItem.id,
      thumbnail: mediaItem.artUri?.toString(),
    );

    final url = await audoraPlayer.getAudioUrl(track.videoId);
    if (url == null) return;

    final item = MediaItem(
      id: track.videoId,
      album: "YouTube",
      title: track.title,
      artist: track.artist,
      artUri: track.thumbnail != null ? Uri.parse(track.thumbnail!) : null,
    );

    await updateQueue([item]);
    await updateMediaItem(item);

    await _player.setUrl(url);

    _player.play();
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  MediaItem? get currentTrack => mediaItem.value;
}
