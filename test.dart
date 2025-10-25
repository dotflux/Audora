import 'lib/audora_music.dart';

void main() async {
  final client = AudoraClient();
  final search = AudoraSearch(client);
  final player = AudoraPlayer(client);

  try {
    final tracks = await search.fetchPlaylist(
      'PLgzTt0k8mXzEk586ze4BjvDXR7c-TUSnx',
    );

    for (var t in tracks) {
      print('Title   : ${t.title}');
      print('Artist  : ${t.artist}');
      print('VideoID : ${t.videoId}');
      print("Thumbnail : ${t.thumbnail}");
      final audioUrl = await player.getAudioUrl(t.videoId);
      print('Audio URL: $audioUrl\n');
    }
  } catch (e) {
    print('Error: $e');
  }
}
