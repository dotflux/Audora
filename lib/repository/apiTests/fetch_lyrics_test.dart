import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import "../../utils/log.dart";

const String lrcBase = 'https://lrclib.net';

Future<Map<String, dynamic>?> getLRCById(int id) async {
  final res = await http.get(Uri.parse('$lrcBase/api/get/$id'));
  if (res.statusCode != 200) return null;
  return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
}

Future<Map<String, dynamic>?> getLRCByQuery({
  required String trackName,
  required String artistName,
  String? albumName,
  int? duration,
}) async {
  final params = <String, String>{
    'track_name': trackName,
    'artist_name': artistName,
  };
  if (albumName != null) params['album_name'] = albumName;
  if (duration != null) params['duration'] = duration.toString();
  final uri = Uri.parse('$lrcBase/api/get').replace(queryParameters: params);
  final res = await http.get(uri);
  if (res.statusCode != 200) return null;
  return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
}

Future<List<Map<String, dynamic>>> searchLRC({
  String? q,
  String? trackName,
  String? artistName,
  String? albumName,
}) async {
  final params = <String, String>{};
  if (q != null) params['q'] = q;
  if (trackName != null) params['track_name'] = trackName;
  if (artistName != null) params['artist_name'] = artistName;
  if (albumName != null) params['album_name'] = albumName;
  final uri = Uri.parse('$lrcBase/api/search').replace(queryParameters: params);
  final res = await http.get(uri);
  if (res.statusCode != 200) return [];
  final data = jsonDecode(utf8.decode(res.bodyBytes));
  return (data as List).cast<Map<String, dynamic>>();
}

void main() {
  test('Fetch lyrics by ID', () async {
    const id = 3396226;
    final lyrics = await getLRCById(id);
    expect(lyrics, isNotNull);

    log.d('Title: ${lyrics!['trackName']}');

    log.d('Artist: ${lyrics['artistName']}');

    log.d('Has synced: ${lyrics['syncedLyrics'] != null}');
    if (lyrics['syncedLyrics'] != null) {
      final synced = lyrics['syncedLyrics'] as String;

      log.d(
        'Synced lyrics preview: ${synced.substring(0, synced.length > 100 ? 100 : synced.length)}...',
      );
    }
  });

  test('Fetch lyrics by track/artist/album/duration', () async {
    final lyrics = await getLRCByQuery(
      trackName: 'I Want to Live',
      artistName: 'Borislav Slavov',
      albumName: 'Baldur\'s Gate 3 (Original Game Soundtrack)',
      duration: 233,
    );
    expect(lyrics, isNotNull);

    log.d('Found: ${lyrics!['trackName']} by ${lyrics['artistName']}');

    log.d('ID: ${lyrics['id']}');
  });

  test('Search lyrics', () async {
    final results = await searchLRC(
      q: 'I Want to Live Borislav',
      artistName: 'Borislav Slavov',
    );
    expect(results, isNotEmpty);

    log.d('Found ${results.length} results:');
    for (final r in results.take(3)) {
      log.d('  - ${r['trackName']} by ${r['artistName']} (ID: ${r['id']})');
    }
  });
}
