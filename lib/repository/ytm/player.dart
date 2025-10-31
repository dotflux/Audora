import 'client.dart';
import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:uri/uri.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class AudoraPlayer {
  final AudoraClient client;
  final YoutubeExplode _yt = YoutubeExplode();

  AudoraPlayer(this.client);

  Future<String?> getAudioUrl(String videoId, {String? visitorData}) async {
    final body = client.baseContext(visitorData: visitorData);
    body['videoId'] = videoId;

    final res = await client.post('player', body);

    final adaptiveFormats = res['streamingData']?['adaptiveFormats'] as List?;
    if (adaptiveFormats == null) return null;

    for (var f in adaptiveFormats) {
      final mimeType = f['mimeType'] as String? ?? '';
      if (!mimeType.startsWith('audio/')) continue;

      if (f['url'] != null) return f['url'] as String;

      if (f['signatureCipher'] != null) {
        final cipher = f['signatureCipher'] as String;
        final params = Uri.splitQueryString(cipher);

        String url = Uri.decodeComponent(params['url'] ?? '');
        final s = params['s'];
        final sp = params['sp'] ?? 'sig';
        if (s != null) {
          url += '&$sp=$s';
        }

        return url;
      }
    }

    return null;
  }

  Future<Map<String, dynamic>?> getAudioFromServer(String videoId) async {
    try {
      final serverUrl = Uri.parse(
        'http://localhost:3000/audio?videoId=$videoId',
      );

      final response = await http
          .get(serverUrl)
          .timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        print(
          '[ERROR] Node proxy returned status ${response.statusCode} for $videoId',
        );
        return null;
      }

      final data = jsonDecode(response.body);
      return data;
    } catch (e, st) {
      print('[ERROR] Failed to fetch audio from Node server: $e');
      print(st);
      return null;
    }
  }

  Future<String?> getAudioUrlExplode(String videoId) async {
    try {
      final manifest = await _yt.videos.streams.getManifest(
        videoId,
        requireWatchPage: true,
        ytClients: [YoutubeApiClient.androidVr],
      );
      final audioOnly = manifest.audioOnly;
      if (audioOnly.isEmpty) return null;
      final best = audioOnly.sortByBitrate().last;
      return best.url.toString();
    } catch (e, st) {
      print('[ERROR] youtube_explode_dart failed for $videoId: $e');
      print(st);
      return null;
    }
  }
}
