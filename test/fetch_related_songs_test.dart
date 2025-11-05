// import 'dart:convert';
// import 'package:flutter_test/flutter_test.dart';
// import 'package:http/http.dart' as http;

// const ytmDomain = 'music.youtube.com';
// const ytmBaseEndpoint = '/youtubei/v1/';
// const ytmParams = {
//   'alt': 'json',
//   'key': 'AIzaSyDJ9lW0bJLwquuJFTMojyMu-Vh1ln-WFqg',
// };
// const userAgent =
//     'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:88.0) Gecko/20100101 Firefox/88.0';

// Map<String, String> initHeaders() {
//   return {
//     'user-agent': userAgent,
//     'accept': '*/*',
//     'accept-encoding': 'gzip, deflate',
//     'content-type': 'application/json',
//     'content-encoding': 'gzip',
//     'origin': 'https://music.youtube.com',
//     'cookie': 'CONSENT=YES+1',
//     'Accept-Language': 'en',
//   };
// }

// Future<String?> getVisitorId(Map<String, String> headers) async {
//   final res = await http.get(Uri.https(ytmDomain), headers: headers);
//   final match = RegExp(
//     r'ytcfg\.set\s*\(\s*({.+?})\s*\)\s*;',
//   ).firstMatch(res.body);
//   if (match == null) return null;
//   final ytcfg = jsonDecode(match.group(1)!) as Map;
//   return ytcfg['VISITOR_DATA']?.toString();
// }

// Map<String, dynamic> initContext({String? visitorId}) {
//   final now = DateTime.now();
//   final date =
//       '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
//   return {
//     'context': {
//       'client': {
//         'clientName': 'WEB_REMIX',
//         'clientVersion': '1.$date.01.00',
//         'hl': 'en',
//         'userAgent': userAgent,
//         if (visitorId != null) 'visitorData': visitorId,
//       },
//       'user': {},
//     },
//   };
// }

// dynamic nav(Map data, List path) {
//   dynamic current = data;
//   for (final key in path) {
//     if (current is Map) {
//       current = current[key];
//     } else if (current is List && key is int && key < current.length) {
//       current = current[key];
//     } else {
//       return null;
//     }
//   }
//   return current;
// }

// Future<List<Map<String, dynamic>>> getRelatedSongs(String videoId) async {
//   final headers = initHeaders();
//   final visitorId = await getVisitorId(headers);
//   headers['X-Goog-Visitor-Id'] = visitorId ?? '';

//   final context = initContext(visitorId: visitorId);
//   final body = Map<String, dynamic>.from(context);
//   body['isAudioOnly'] = true;
//   body['videoId'] = videoId;
//   body['enablePersistentPlaylistPanel'] = true;
//   body['tunerSettingValue'] = 'AUTOMIX_SETTING_NORMAL';
//   body['params'] = 'wAEB';

//   final uri = Uri.https(ytmDomain, '${ytmBaseEndpoint}next', ytmParams);
//   final res = await http.post(uri, headers: headers, body: jsonEncode(body));

//   if (res.statusCode != 200) {
//     throw Exception('YT Music API error: ${res.statusCode}');
//   }

//   final data = jsonDecode(res.body) as Map;

//   final playlistId = nav(data, [
//     'contents',
//     'singleColumnMusicWatchNextResultsRenderer',
//     'tabbedRenderer',
//     'watchNextTabbedResultsRenderer',
//     'tabs',
//     0,
//     'tabRenderer',
//     'content',
//     'musicQueueRenderer',
//     'content',
//     'playlistPanelRenderer',
//     'contents',
//     1,
//     'automixPreviewVideoRenderer',
//     'content',
//     'automixPlaylistVideoRenderer',
//     'navigationEndpoint',
//     'watchPlaylistEndpoint',
//     'playlistId',
//   ])?.toString();

//   if (playlistId == null) return [];

//   body['playlistId'] = playlistId;
//   final res2 = await http.post(uri, headers: headers, body: jsonEncode(body));

//   if (res2.statusCode != 200) {
//     throw Exception('YT Music API error (2): ${res2.statusCode}');
//   }

//   final data2 = jsonDecode(res2.body) as Map;
//   final items =
//       (nav(data2, [
//             'contents',
//             'singleColumnMusicWatchNextResultsRenderer',
//             'tabbedRenderer',
//             'watchNextTabbedResultsRenderer',
//             'tabs',
//             0,
//             'tabRenderer',
//             'content',
//             'musicQueueRenderer',
//             'content',
//             'playlistPanelRenderer',
//             'contents',
//           ])
//           as List?) ??
//       [];

//   final List<Map<String, dynamic>> results = [];

//   for (final item in items) {
//     try {
//       final itemMap = item as Map;
//       final renderer = itemMap['playlistPanelVideoRenderer'] as Map?;
//       if (renderer == null) continue;

//       final title =
//           nav(renderer, ['title', 'runs', 0, 'text'])?.toString() ?? '';
//       final vidId = nav(renderer, ['videoId'])?.toString();
//       if (vidId == null) continue;

//       final image =
//           nav(renderer, ['thumbnail', 'thumbnails', 0, 'url'])?.toString() ??
//           '';
//       final duration =
//           nav(renderer, ['lengthText', 'runs', 0, 'text'])?.toString() ?? '';

//       final subtitleList =
//           (nav(renderer, ['longBylineText', 'runs']) as List?) ?? [];
//       String artists = '';
//       String album = '';
//       int count = 0;

//       for (final element in subtitleList) {
//         final elMap = element as Map;
//         if (elMap['text']?.toString().trim() == '•') {
//           count++;
//         } else {
//           if (count == 0) {
//             artists += elMap['text']?.toString() ?? '';
//           } else if (count == 1 && subtitleList.length > 2) {
//             album += elMap['text']?.toString() ?? '';
//           }
//         }
//       }

//       if (album.contains('views')) album = '';

//       results.add({
//         'videoId': vidId,
//         'title': title,
//         'artists': artists,
//         'album': album,
//         'duration': duration,
//         'image': image,
//       });
//     } catch (e) {
//       // ignore
//     }
//   }

//   return results;
// }

// void main() {
//   test('Fetch related songs for YouTube video', () async {
//     const videoId = 'mJ1N7-HyH1A';

//     final related = await getRelatedSongs(videoId);
//     expect(related, isNotEmpty);

//     print('Found ${related.length} related songs:');
//     for (final song in related.take(10)) {
//       print('${song['videoId']}\t${song['title']}\t${song['artists']}');
//     }
//   });
// }
