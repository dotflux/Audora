import 'dart:convert';
import 'package:http/http.dart' as http;
import 'track.dart';
import 'client.dart';

class AudoraCharts {
  final AudoraClient client;
  AudoraCharts(this.client);

  Future<List<Track>> fetchTrendingTracks({String countryCode = 'IN'}) async {
    return _fetchCharts(
      chartType: 'TRACKS',
      chartId: 'regional',
      countryCode: countryCode,
    );
  }

  Future<List<Track>> fetchGlobalTopCharts() async {
    return _fetchCharts(
      chartType: 'TRACKS',
      chartId: 'mostPopular',
      countryCode: 'US',
      isGlobal: true,
    );
  }

  Future<List<Track>> _fetchCharts({
    required String chartType,
    required String chartId,
    required String countryCode,
    bool isGlobal = false,
  }) async {
    final keySource = isGlobal ? 'US' : countryCode;
    final response = await http.get(
      Uri.parse('https://charts.youtube.com/charts/TrendingVideos/$keySource'),
    );

    final keyRegex = RegExp(r'"INNERTUBE_API_KEY"\s*:\s*"(.*?)"');
    final apiKey = keyRegex.firstMatch(response.body)?.group(1);
    if (apiKey == null) throw Exception('Failed to extract INNERTUBE_API_KEY');

    final queryParams = [
      'perspective=CHART_DETAILS',
      'chart_params_chart_type=$chartType',
      'chart_params_chart_id=$chartId',
      'chart_params_period_type=WEEKLY',
      if (!isGlobal) 'chart_params_country_code=$countryCode',
    ].join('&');

    final data = {
      "context": {
        "client": {
          "clientName": "WEB_MUSIC_ANALYTICS",
          "clientVersion": "2.0",
          "hl": "en",
          "gl": countryCode,
          "theme": "MUSIC",
        },
      },
      "browseId": "FEmusic_analytics_charts_home",
      "query": queryParams,
    };

    final chartResponse = await http.post(
      Uri.parse(
        'https://charts.youtube.com/youtubei/v1/browse?alt=json&key=$apiKey',
      ),
      headers: {
        'Referer':
            'https://charts.youtube.com/charts/TrendingVideos/$keySource',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(data),
    );

    if (chartResponse.statusCode != 200) {
      throw Exception('Failed to load charts: ${chartResponse.statusCode}');
    }

    final jsonData = jsonDecode(chartResponse.body);
    final trackViews =
        jsonData["contents"]?['sectionListRenderer']?["contents"]?[0]?['musicAnalyticsSectionRenderer']?['content']?['trackTypes']?[0]?["trackViews"] ??
        [];

    final List<Track> tracks = [];

    for (var item in trackViews.take(20)) {
      final title = item['name'] ?? 'Unknown Title';
      String thumbnail = '';
      try {
        final thumbs = item['thumbnail']?['thumbnails'] as List?;
        if (thumbs != null && thumbs.isNotEmpty) {
          final best = thumbs.reduce((a, b) {
            final aw = (a['width'] ?? 0) as int;
            final bw = (b['width'] ?? 0) as int;
            return bw > aw ? b : a;
          });
          thumbnail = best['url'] ?? '';
        }
      } catch (_) {}

      final artists =
          (item['artists'] as List?)
              ?.map((a) => a['name']?.toString())
              .whereType<String>()
              .toList() ??
          ['Unknown Artist'];

      final videoId =
          item['encryptedVideoId'] ?? item['atvExternalVideoId'] ?? '';

      if (videoId.isNotEmpty) {
        tracks.add(
          Track(
            title: title,
            artist: artists.join(', '),
            videoId: videoId,
            thumbnail: thumbnail,
          ),
        );
      }
    }

    return tracks;
  }
}
