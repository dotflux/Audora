import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../utils/log.dart';

class AudoraClient {
  String? _cachedVisitorData;
  Future<String?>? _visitorDataFuture;

  String? get cachedVisitorData => _cachedVisitorData;

  String get currentClientVersion {
    final now = DateTime.now();
    final y = now.year;
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '1.$y$m$d.01.00';
  }

  Map<String, String> defaultHeaders({String? visitorData}) => {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:88.0) Gecko/20100101 Firefox/88.0',
    'Accept': '*/*',
    'Accept-Language': 'en-US,en;q=0.9',
    'Origin': 'https://music.youtube.com',
    'Referer': 'https://music.youtube.com',
    'Content-Type': 'application/json',
    'x-goog-visitor-id': visitorData ?? _cachedVisitorData ?? '',
    'Cookie': 'CONSENT=YES+1',
  };

  Future<String?> getVisitorData({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedVisitorData != null) {
      return _cachedVisitorData;
    }

    if (_visitorDataFuture != null && !forceRefresh) {
      return await _visitorDataFuture;
    }

    _visitorDataFuture = _fetchVisitorData();
    try {
      _cachedVisitorData = await _visitorDataFuture;
      return _cachedVisitorData;
    } finally {
      _visitorDataFuture = null;
    }
  }

  Future<String?> _fetchVisitorData() async {
    log.d('🔍 Starting visitorData fetch...');
    try {
      final res = await http
          .get(
            Uri.parse('https://music.youtube.com'),
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:88.0) Gecko/20100101 Firefox/88.0',
            },
          )
          .timeout(const Duration(seconds: 5));

      final reg = RegExp(r'ytcfg\.set\s*\(\s*({.+?})\s*\)\s*;');
      final match = reg.firstMatch(res.body);
      if (match != null) {
        final ytcfg = jsonDecode(match.group(1)!);
        final visitorData = ytcfg['VISITOR_DATA']?.toString();
        if (visitorData != null) {
          _cachedVisitorData = visitorData;
          log.d('✅ VisitorData fetched and cached');
          return visitorData;
        }
      }
      log.d('⚠️ No visitorData found in response');
    } catch (e) {
      log.d('❌ Failed to fetch visitor data: $e');
    }
    log.d('📦 Returning cached visitorData: $_cachedVisitorData');
    return _cachedVisitorData;
  }

  void ensureVisitorData() {
    if (_cachedVisitorData == null && _visitorDataFuture == null) {
      log.d('🚀 Starting background visitorData fetch...');
      _visitorDataFuture = _fetchVisitorData();
      _visitorDataFuture!
          .then((v) {
            _cachedVisitorData = v;
            _visitorDataFuture = null;
            log.d('✅ Background visitorData fetch completed');
          })
          .catchError((e) {
            log.d('❌ Background visitorData fetch failed: $e');
            _visitorDataFuture = null;
          });
    } else {
      log.d('📦 VisitorData already cached or fetching: $_cachedVisitorData');
    }
  }

  Map<String, dynamic> baseContext({String? visitorData}) => {
    'context': {
      'client': {
        'clientName': 'WEB_REMIX',
        'clientVersion': currentClientVersion,
        'userAgent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:88.0) Gecko/20100101 Firefox/88.0',
      },
      'user': {},
      'visitorData': visitorData ?? '',
    },
  };

  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body, {
    String? visitorData,
  }) async {
    final uri = Uri.parse(
      'https://music.youtube.com/youtubei/v1/$endpoint?key=AIzaSyDJ9lW0bJLwquuJFTMojyMu-Vh1ln-WFqg',
    );

    final effectiveVisitorData = visitorData ?? _cachedVisitorData ?? '';
    final headers = defaultHeaders(visitorData: effectiveVisitorData);

    final response = await http
        .post(uri, headers: headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 10));

    log.d('HTTP ${response.statusCode} for $endpoint');

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> postYT(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse(
      'https://www.youtube.com/youtubei/v1/$endpoint?key=AIzaSyA8EiYV-KXzN0nEUTT9ZCsmvZ9YjV_r1QY',
    );

    final headers = {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:88.0) Gecko/20100101 Firefox/88.0',
      'Accept': '*/*',
      'Accept-Language': 'en-US,en;q=0.9',
      'Origin': 'https://www.youtube.com',
      'Referer': 'https://www.youtube.com',
      'Content-Type': 'application/json',
      'Cookie': 'CONSENT=YES+1',
    };

    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode(body),
    );

    log.d('HTTP ${response.statusCode} for YT $endpoint');

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
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

  Future<List<Map<String, dynamic>>> ytSearchRaw(String query) async {
    try {
      final uri = Uri.parse(
        'https://www.youtube.com/results?search_query=' +
            Uri.encodeComponent(query),
      );
      final res = await http
          .get(
            uri,
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36',
              'Accept-Language': 'en-US,en;q=0.9',
            },
          )
          .timeout(const Duration(seconds: 25));
      if (res.statusCode != 200) return [];
      final body = res.body;
      final m =
          RegExp(r'var ytInitialData = (\{[\s\S]*?\});').firstMatch(body) ??
          RegExp(r'"ytInitialData":(\{[\s\S]*?\})[,<]').firstMatch(body);
      if (m == null) return [];
      var jsonStr = m.group(1)!;
      if (jsonStr.endsWith(';')) {
        jsonStr = jsonStr.substring(0, jsonStr.length - 1);
      }
      Map<String, dynamic> data;
      try {
        data = jsonDecode(jsonStr) as Map<String, dynamic>;
      } catch (_) {
        return [];
      }

      final List<Map<String, dynamic>> out = [];
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
            final titleRuns =
                (((v['title'] ?? {}) as Map)['runs'] ?? []) as List;
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
            String? thumb;
            try {
              final thumbs =
                  (((v['thumbnail'] ?? {}) as Map)['thumbnails'] ?? []) as List;
              if (thumbs.isNotEmpty) {
                final best = (thumbs as List).cast<Map>().reduce((a, b) {
                  final aw = (a['width'] as int?) ?? 0;
                  final bw = (b['width'] as int?) ?? 0;
                  return bw > aw ? b : a;
                });
                thumb = best['url'] as String?;
              }
            } catch (_) {}
            out.add({
              'id': videoId,
              'title': title,
              'channel': channel,
              'duration': durSec,
              'thumb': thumb,
            });
          }
        }
      } catch (_) {}
      return out;
    } catch (_) {
      return [];
    }
  }
}
