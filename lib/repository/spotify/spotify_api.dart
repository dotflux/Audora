import 'dart:convert';
import 'package:http/http.dart' as http;

class SpotifyApi {
  final String clientId = "4e088e81db714fb682f11d2c7385a9ec";
  final String clientSecret = "baea92596e9c4d51b0a7dbc775792853";
  String? _accessToken;

  Future<String> _getAccessToken() async {
    if (_accessToken != null) return _accessToken!;
    final uri = Uri.parse('https://accounts.spotify.com/api/token');
    final basic = base64Encode(utf8.encode('$clientId:$clientSecret'));
    final res = await http.post(
      uri,
      headers: {'Authorization': 'Basic $basic'},
      body: {'grant_type': 'client_credentials'},
    );
    if (res.statusCode != 200) {
      throw Exception('Spotify token error: ${res.statusCode} ${res.body}');
    }
    final json = jsonDecode(res.body) as Map;
    _accessToken = json['access_token'] as String;
    return _accessToken!;
  }

  Future<Map<String, dynamic>> getPlaylist(String playlistId) async {
    final token = await _getAccessToken();
    final res = await http.get(
      Uri.parse('https://api.spotify.com/v1/playlists/$playlistId'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
    if (res.statusCode != 200) {
      throw Exception('Spotify playlist error: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getAllPlaylistTracks(
    String playlistId,
  ) async {
    final token = await _getAccessToken();
    final List<Map<String, dynamic>> out = [];
    String url =
        'https://api.spotify.com/v1/playlists/$playlistId/tracks?limit=100';
    while (true) {
      final res = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (res.statusCode != 200) {
        throw Exception('Spotify tracks error: ${res.statusCode} ${res.body}');
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final items = (data['items'] as List?)?.cast<Map>() ?? const [];
      for (final e in items) {
        final track = (e['track'] as Map?) ?? const {};
        if (track.isEmpty) continue;
        final name = (track['name'] ?? '').toString();
        final artists = ((track['artists'] as List?) ?? const [])
            .map((a) => (a as Map)['name'])
            .join(', ');
        final album = (track['album'] as Map?) ?? const {};
        final images = ((album['images'] as List?) ?? const []).cast<Map>();
        String? imageUrl;
        if (images.isNotEmpty) imageUrl = (images.first['url'] as String?);
        final durMs = (track['duration_ms'] as int?) ?? 0;
        out.add({
          'title': name,
          'artists': artists,
          'durationSec': (durMs / 1000).round(),
          'albumArt': imageUrl,
        });
      }
      final next = data['next'] as String?;
      if (next == null) break;
      url = next;
    }
    return out;
  }

  Future<List<Map<String, dynamic>>> searchTracks(
    String query, {
    int limit = 20,
  }) async {
    final token = await _getAccessToken();
    final uri = Uri.parse(
      'https://api.spotify.com/v1/search?q=${Uri.encodeComponent(query)}&type=track&limit=${limit.clamp(1, 50)}',
    );

    final res = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );

    if (res.statusCode != 200) {
      return [];
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final tracksData = data['tracks'] as Map<String, dynamic>?;
    final items = (tracksData?['items'] as List?)?.cast<Map>() ?? [];

    final List<Map<String, dynamic>> out = [];

    for (final item in items) {
      final name = (item['name'] ?? '').toString();
      final artists = ((item['artists'] as List?) ?? const [])
          .map((a) => (a as Map)['name'])
          .join(', ');
      final album = (item['album'] as Map?) ?? const {};
      final images = ((album['images'] as List?) ?? const []).cast<Map>();
      String? imageUrl;
      if (images.isNotEmpty) {
        imageUrl = (images.first['url'] as String?);
      }
      final durMs = (item['duration_ms'] as int?) ?? 0;
      out.add({
        'title': name,
        'artists': artists,
        'durationSec': (durMs / 1000).round(),
        'albumArt': imageUrl,
      });
    }

    return out;
  }
}
