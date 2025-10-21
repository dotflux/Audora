import 'dart:convert';
import 'package:http/http.dart' as http;

class AudoraClient {
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
    'x-goog-visitor-id': visitorData ?? '',
    'Cookie': 'CONSENT=YES+1',
  };

  Future<String?> getVisitorData() async {
    final res = await http.get(
      Uri.parse('https://music.youtube.com'),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:88.0) Gecko/20100101 Firefox/88.0',
      },
    );

    final reg = RegExp(r'ytcfg\.set\s*\(\s*({.+?})\s*\)\s*;');
    final match = reg.firstMatch(res.body);
    if (match != null) {
      final ytcfg = jsonDecode(match.group(1)!);
      return ytcfg['VISITOR_DATA']?.toString();
    }
    return null;
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

    final headers = defaultHeaders(visitorData: visitorData);

    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode(body),
    );

    print('HTTP ${response.statusCode} for $endpoint');

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

    print('HTTP ${response.statusCode} for YT $endpoint');

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
