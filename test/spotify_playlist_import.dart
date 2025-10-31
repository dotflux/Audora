import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

Future<String> _getSpotifyTokenDirect() async {
  const clientID = 'id';
  const clientSecret = 'secret';
  final uri = Uri.parse('https://accounts.spotify.com/api/token');
  final basic = base64Encode(utf8.encode('$clientID:$clientSecret'));
  final res = await http.post(
    uri,
    headers: {'Authorization': 'Basic $basic'},
    body: {'grant_type': 'client_credentials'},
  );
  if (res.statusCode != 200) {
    throw Exception('Spotify token error: ${res.statusCode} ${res.body}');
  }
  final json = jsonDecode(res.body) as Map;
  return json['access_token'] as String;
}

Future<List<Map>> _getAllPlaylistTracks(
  String accessToken,
  String playlistId,
) async {
  final List<Map> out = [];
  String url =
      'https://api.spotify.com/v1/playlists/$playlistId/tracks?limit=100';
  while (true) {
    final res = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
      },
    );
    if (res.statusCode != 200) {
      throw Exception(
        'Spotify tracks error: \\${res.statusCode} \\${res.body}',
      );
    }
    final data = jsonDecode(res.body) as Map;
    out.addAll(((data['items'] as List?) ?? const []).cast<Map>());
    final next = data['next'] as String?;
    if (next == null) break;
    url = next;
  }
  return out;
}

int _parseDurationToSeconds(String s) {
  final parts = s.split(':').map((e) => e.trim()).toList();
  if (parts.length == 3) {
    return int.parse(parts[0]) * 3600 +
        int.parse(parts[1]) * 60 +
        int.parse(parts[2]);
  } else if (parts.length == 2) {
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }
  return 0;
}

String _norm(String s) {
  return s
      .toLowerCase()
      .replaceAll(RegExp(r'\([^\)]*\)|\[[^\]]*\]'), ' ')
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

bool _containsBadTag(String s) {
  final ls = s.toLowerCase();
  return ls.contains('live') ||
      ls.contains('cover') ||
      ls.contains('remix') ||
      ls.contains('sped up') ||
      ls.contains('slowed') ||
      ls.contains('nightcore');
}

Future<List<Map<String, dynamic>>> _ytSearchCandidates(String query) async {
  final uri = Uri.parse(
    'https://www.youtube.com/results?search_query=' +
        Uri.encodeComponent(query),
  );
  final res = await http.get(
    uri,
    headers: {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36',
      'Accept-Language': 'en-US,en;q=0.9',
    },
  );
  if (res.statusCode != 200) return [];
  final body = res.body;

  final initMatch =
      RegExp(r'var ytInitialData = (\{[\s\S]*?\});').firstMatch(body) ??
      RegExp(r'"ytInitialData":(\{[\s\S]*?\})[,<]').firstMatch(body);
  if (initMatch == null) return [];
  var jsonStr = initMatch.group(1)!;
  if (jsonStr.endsWith(';')) jsonStr = jsonStr.substring(0, jsonStr.length - 1);

  Map data;
  try {
    data = jsonDecode(jsonStr) as Map;
  } catch (_) {
    return [];
  }

  List<Map<String, dynamic>> out = [];
  try {
    final contents =
        (((data['contents'] as Map)['twoColumnSearchResultsRenderer']
                    as Map)['primaryContents']
                as Map)['sectionListRenderer']
            as Map;
    final sections = (contents['contents'] as List).cast<Map>();
    for (final sec in sections) {
      final items =
          (((sec['itemSectionRenderer'] ?? {}) as Map)['contents'] ?? [])
              as List;
      for (final it in items) {
        final v = it['videoRenderer'] as Map?;
        if (v == null) continue;
        final videoId = v['videoId'] as String?;
        if (videoId == null) continue;
        final titleRuns = (((v['title'] ?? {}) as Map)['runs'] ?? []) as List;
        final title = titleRuns.isNotEmpty
            ? (titleRuns.first['text'] as String? ?? '')
            : '';
        final lengthText =
            ((v['lengthText'] ?? {}) as Map)['simpleText'] as String?;
        final channelRuns =
            ((((v['ownerText'] ?? {}) as Map)['runs'] ?? []) as List);
        final channel = channelRuns.isNotEmpty
            ? (channelRuns.first['text'] as String? ?? '')
            : '';
        final durSec = lengthText != null
            ? _parseDurationToSeconds(lengthText)
            : 0;
        out.add({
          'id': videoId,
          'title': title,
          'channel': channel,
          'duration': durSec,
        });
      }
    }
  } catch (_) {}
  return out;
}

Map<String, dynamic>? _pickBestCandidate({
  required List<Map<String, dynamic>> cands,
  required String songTitle,
  required String songArtists,
  required int targetDurSec,
}) {
  if (cands.isEmpty) return null;
  final targetTitle = _norm('$songTitle');
  final targetArtists = _norm('$songArtists');

  int bestScore = -999999;
  Map<String, dynamic>? best;
  for (final c in cands) {
    final title = c['title'] as String? ?? '';
    final channel = c['channel'] as String? ?? '';
    final dur = (c['duration'] as int?) ?? 0;
    final nTitle = _norm(title);
    final nChan = _norm(channel);

    final tTokens = targetTitle.split(' ').toSet();
    final aTokens = targetArtists.split(' ').toSet();
    final cTokens = nTitle.split(' ').toSet();
    final overlap =
        tTokens.intersection(cTokens).length +
        aTokens.intersection(cTokens).length;

    final dd = (dur - targetDurSec).abs();
    int durScore = dd <= 3
        ? 30
        : dd <= 5
        ? 20
        : dd <= 10
        ? 10
        : -dd;

    int chanScore = (nChan.endsWith(' topic') || nChan.contains('topic'))
        ? 25
        : 0;
    int badPenalty = _containsBadTag(title) ? -30 : 0;

    final score = overlap * 3 + durScore + chanScore + badPenalty;
    if (score > bestScore) {
      bestScore = score;
      best = c;
    }
  }
  return best;
}

void main() {
  const String playlistId = '0nnDMNEyvNjDz2b7h9g1hn';

  test(
    'Map Spotify playlist tracks to YouTube videoIds (accurate, raw HTTP only)',
    () async {
      if (playlistId.isEmpty) {
        print('Provide a playlistId in the test file.');
        return;
      }

      final token = await _getSpotifyTokenDirect();
      final tracks = await _getAllPlaylistTracks(token, playlistId);

      print('Tracks fetched: ${tracks.length}');
      int mapped = 0;
      const int MAX_TRACKS = 40;
      int processed = 0;
      for (final e in tracks) {
        if (processed >= MAX_TRACKS) break;
        final track = e['track'] as Map?;
        if (track == null) continue;
        final title = (track['name'] ?? '').toString();
        final artists = ((track['artists'] as List?) ?? const [])
            .map((a) => (a as Map)['name'])
            .join(', ');
        final durMs = (track['duration_ms'] as int?) ?? 0;
        final durSec = (durMs / 1000).round();
        final query = '$title $artists'.trim();
        if (query.isEmpty) continue;

        final cands = await _ytSearchCandidates('$query official audio');
        final best =
            _pickBestCandidate(
              cands: cands,
              songTitle: title,
              songArtists: artists,
              targetDurSec: durSec,
            ) ??
            _pickBestCandidate(
              cands: await _ytSearchCandidates(query),
              songTitle: title,
              songArtists: artists,
              targetDurSec: durSec,
            );
        if (best != null) {
          mapped++;

          print('${best['id']}\t$query');
        } else {
          print('MISS\t$query');
        }
        processed++;
      }

      print('Mapped $mapped/${processed}');
    },
  );
}
