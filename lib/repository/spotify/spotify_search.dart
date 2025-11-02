import 'package:audora/audora_music.dart';
import 'spotify_api.dart';
import '../ytm/client.dart';

class SpotifySearch {
  final SpotifyApi api;
  final AudoraClient ytmClient;

  SpotifySearch({required this.api, required this.ytmClient});

  Future<List<Track>> search(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) return [];

    final spotifyTracks = await api.searchTracks(query, limit: limit);
    final List<Track> tracks = [];

    for (final item in spotifyTracks) {
      final name = item['title']?.toString() ?? '';
      final artists = item['artists']?.toString() ?? '';
      String? imageUrl = item['albumArt']?.toString();
      final durationSec = (item['durationSec'] as int?) ?? 0;

      if (name.isEmpty) continue;

      String searchQuery = '$name $artists official audio';
      Map<String, dynamic>? best;
      for (int attempt = 0; attempt < 2; attempt++) {
        try {
          final res1 = await ytmClient
              .ytSearchRaw(searchQuery)
              .timeout(const Duration(seconds: 20));
          best = _pickBestRaw(res1, name, artists, durationSec);
          if (best == null && attempt == 0) {
            final res2 = await ytmClient
                .ytSearchRaw('$name $artists')
                .timeout(const Duration(seconds: 20));
            best = _pickBestRaw(res2, name, artists, durationSec);
          }
          if (best != null) break;
        } catch (_) {}
        if (attempt < 1) {
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }

      if (best != null) {
        imageUrl ??= best['thumb'] as String?;
        tracks.add(
          Track(
            title: name,
            artist: artists,
            videoId: best['id'] as String,
            thumbnail: imageUrl,
            durationSec: durationSec,
          ),
        );
      }
    }

    return tracks;
  }

  Map<String, dynamic>? _pickBestRaw(
    List<Map<String, dynamic>> cands,
    String title,
    String artists,
    int durSec,
  ) {
    String norm(String s) => s
        .toLowerCase()
        .replaceAll(RegExp(r'\([^)]+\)|\[[^]]+\]'), ' ')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final tTitle = norm(title);
    final tArtists = norm(artists);
    int bestScore = -0x3fffffff;
    Map<String, dynamic>? best;
    for (final c in cands) {
      final nTitle = norm((c['title'] as String? ?? ''));
      final chan = (c['channel'] as String? ?? '').toLowerCase();
      final candDur = (c['duration'] as int?) ?? 0;
      final tokensT = tTitle.split(' ').toSet();
      final tokensA = tArtists.split(' ').toSet();
      final tokensC = nTitle.split(' ').toSet();
      final overlap =
          tokensT.intersection(tokensC).length +
          tokensA.intersection(tokensC).length;
      final dd = (candDur - durSec).abs();
      final durScore = dd <= 3
          ? 30
          : dd <= 5
          ? 20
          : dd <= 10
          ? 10
          : -dd;
      final chanScore = (chan.endsWith(' topic') || chan.contains('topic'))
          ? 25
          : 0;
      int bad = 0;
      final low = (c['title'] as String? ?? '').toLowerCase();
      if (low.contains('live') ||
          low.contains('cover') ||
          low.contains('remix') ||
          low.contains('sped up') ||
          low.contains('slowed') ||
          low.contains('nightcore'))
        bad = -30;
      final wantInstrumental = tTitle.contains('instrumental');
      final candInstrumental =
          low.contains('instrumental') || low.contains('karaoke');
      if (!wantInstrumental && candInstrumental) bad -= 40;
      if (!tTitle.contains('lyrics') &&
          (low.contains('lyrics') || low.contains('lyric')))
        bad -= 15;
      if (overlap < (tokensT.length / 2).ceil()) bad -= 20;
      final score = overlap * 3 + durScore + chanScore + bad;
      if (score > bestScore) {
        bestScore = score;
        best = c;
      }
    }
    return best;
  }
}
