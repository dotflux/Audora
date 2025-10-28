import 'lib/audora_music.dart';

void main() async {
  final client = AudoraClient();
  final search = AudoraSearch(client);
  final player = AudoraPlayer(client);
  final charts = AudoraCharts(client);

  try {
    final romance = await search.fetchGenreSongs('romance');
    final phonk = await search.fetchGenreSongs('phonk', limit: 30);

    print('❤️ romance songs: ${romance.length}');
    for (final t in romance) {
      print('${t.title} — ${t.artist} - ${t.videoId} - ${t.thumbnail}');
    }

    print('\n😈 phonk songs: ${phonk.length}');
    for (final t in phonk) {
      print("${t.title} - ${t.artist} - ${t.videoId} - ${t.thumbnail}");
    }
  } catch (e) {
    print('Error: $e');
  }
}
