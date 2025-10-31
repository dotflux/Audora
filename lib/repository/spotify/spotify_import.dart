import 'dart:async';
import 'package:audora/audora_music.dart';
import 'spotify_api.dart';
import '../../data/custom_playlists.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class SpotifyImporter {
  final SpotifyApi api;
  final AudoraClient ytmClient;

  SpotifyImporter({required this.api, required this.ytmClient});

  String? extractPlaylistId(String urlOrId) {
    final trimmed = urlOrId.trim();
    final idOnly = RegExp(r'^[A-Za-z0-9]+$').hasMatch(trimmed)
        ? trimmed
        : RegExp(r'playlist/([A-Za-z0-9]+)').firstMatch(trimmed)?.group(1);
    return idOnly;
  }

  Future<void> importPlaylist(
    String playlistId, {
    String? targetName,
    void Function(int done, int total)? onProgress,
  }) async {
    final playlistData = await api.getPlaylist(playlistId);
    final name = targetName ?? (playlistData['name']?.toString() ?? 'Spotify');
    await CustomPlaylists.createPlaylist(name);

    try {
      final images = (playlistData['images'] as List?)?.cast<Map>();
      final coverUrl = (images != null && images.isNotEmpty)
          ? (images.first['url'] as String?)
          : null;
      if (coverUrl != null) {
        final tmp = await _downloadToTemp(coverUrl);
        if (tmp != null) {
          await CustomPlaylists.setCoverImage(name, tmp.path);
        }
      }
    } catch (_) {}

    final tracks = await api.getAllPlaylistTracks(playlistId);
    final total = tracks.length;
    int done = 0;
    for (final t in tracks) {
      final title = t['title']?.toString() ?? '';
      final artists = t['artists']?.toString() ?? '';
      String? albumArt = t['albumArt']?.toString();
      final durationSec = (t['durationSec'] as int?) ?? 0;
      if (title.isEmpty) {
        done++;
        onProgress?.call(done, total);
        continue;
      }
      String query = '$title $artists official audio';
      Map<String, dynamic>? best;
      for (int attempt = 0; attempt < 3; attempt++) {
        try {
          final res1 = await ytmClient
              .ytSearchRaw(query)
              .timeout(const Duration(seconds: 25));
          best = _pickBestRaw(res1, title, artists, durationSec);
          if (best == null && attempt == 0) {
            final res2 = await ytmClient
                .ytSearchRaw('$title $artists')
                .timeout(const Duration(seconds: 25));
            best = _pickBestRaw(res2, title, artists, durationSec);
          }
          if (best != null) break;
        } catch (_) {}
        await Future.delayed(Duration(milliseconds: 400 * (attempt + 1)));
      }
      if (best != null) {
        albumArt ??= best['thumb'] as String?;
        final track = Track(
          title: title,
          artist: artists,
          videoId: best['id'] as String,
          thumbnail: albumArt,
          durationSec: durationSec,
        );
        await CustomPlaylists.addTrack(name, track);
      }
      done++;
      onProgress?.call(done, total);
      await Future.delayed(const Duration(milliseconds: 120));
    }
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

  Future<File?> _downloadToTemp(String url) async {
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200) return null;
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/sp_cover_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await file.writeAsBytes(res.bodyBytes);
      return file;
    } catch (_) {
      return null;
    }
  }
}
