import 'client.dart';
import 'track.dart';
import 'params.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AudoraSearch {
  final AudoraClient client;

  AudoraSearch(this.client);

  Future<List<Track>> search(
    String query, {
    String filter = Params.songs,
    int limit = 20,
    String? visitorData,
  }) async {
    final body = Map<String, dynamic>.from(
      client.baseContext(visitorData: visitorData),
    );
    body['query'] = query;
    body['params'] = filter;

    final res = await client.post('search', body);

    final tabs =
        res['contents']?['tabbedSearchResultsRenderer']?['tabs'] as List?;
    if (tabs == null || tabs.isEmpty) {
      print('No tabs found in response');
      return [];
    }

    final sections =
        tabs[0]?['tabRenderer']?['content']?['sectionListRenderer']?['contents']
            as List?;
    if (sections == null) {
      print('No sections found in first tab');
      return [];
    }

    final tracks = <Track>[];

    for (var section in sections) {
      List? items;

      if (section['musicShelfRenderer'] != null) {
        items = section['musicShelfRenderer']['contents'] as List?;
      } else if (section['musicCardShelfRenderer'] != null) {
        items = section['musicCardShelfRenderer']['contents'] as List?;
      } else {
        print('Unknown section type: ${section.keys}');
        continue;
      }

      if (items == null) continue;

      for (var item in items) {
        final renderer = item['musicResponsiveListItemRenderer'];
        if (renderer == null) {
          print('No musicResponsiveListItemRenderer found');
          continue;
        }

        final flexColumns = renderer['flexColumns'] as List? ?? [];
        String title = '';
        String artist = '';

        if (flexColumns.isNotEmpty) {
          final titleRuns =
              flexColumns[0]?['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs']
                  as List?;
          if (titleRuns != null && titleRuns.isNotEmpty) {
            title = titleRuns[0]?['text'] ?? '';
          }

          for (var i = 1; i < flexColumns.length; i++) {
            final runs =
                flexColumns[i]?['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs']
                    as List?;
            if (runs != null) {
              for (var run in runs) {
                if (run['navigationEndpoint']?['browseEndpoint'] != null) {
                  artist = run['text'] ?? '';
                  break;
                }
              }
            }
            if (artist.isNotEmpty) break;
          }
        }

        // VideoID
        String videoId =
            renderer['navigationEndpoint']?['watchEndpoint']?['videoId'] ??
            renderer['overlay']?['musicItemThumbnailOverlayRenderer']?['content']?['musicPlayButtonRenderer']?['playNavigationEndpoint']?['watchEndpoint']?['videoId'] ??
            '';

        // Thumbnail
        final thumbs =
            renderer['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails']
                as List?;
        String? thumbnail;
        if (thumbs != null && thumbs.isNotEmpty) {
          thumbnail = thumbs.last['url'];
        }
        if (thumbnail != null) {
          thumbnail = thumbnail!.replaceAll(
            RegExp(r'=w\d+-h\d+'),
            '=w1080-h1080',
          );
        }

        if (videoId.isNotEmpty) {
          tracks.add(
            Track(
              title: title,
              artist: artist,
              videoId: videoId,
              thumbnail: thumbnail,
            ),
          );
          if (tracks.length >= limit) break;
        }
      }

      if (tracks.length >= limit) break;
    }

    return tracks;
  }

  Future<List<Track>> fetchPlaylist(String playlistId, {int limit = 50}) async {
    final tracks = <Track>[];

    String? continuationToken;

    void _collectFromNode(dynamic node) {
      if (node == null) return;
      if (node is List) {
        for (final e in node) _collectFromNode(e);
        return;
      }
      if (node is Map<String, dynamic>) {
        if (node['playlistVideoRenderer'] != null) {
          final p = node['playlistVideoRenderer'] as Map<String, dynamic>;
          final videoId = p['videoId'] ?? '';
          String title = '';
          final titleRuns = p['title']?['runs'] as List?;
          if (titleRuns != null && titleRuns.isNotEmpty) {
            title = titleRuns.map((r) => r['text'] ?? '').join();
          }
          String artist = '';
          final shortByline = p['shortBylineText']?['runs'] as List?;
          if (shortByline != null && shortByline.isNotEmpty) {
            artist = shortByline[0]['text'] ?? '';
          }

          String? thumbnail;
          final thumbs = (p['thumbnail']?['thumbnails'] as List?) ?? [];
          if (thumbs.isNotEmpty) thumbnail = thumbs.last['url']?.toString();

          if ((videoId as String).isNotEmpty) {
            tracks.add(
              Track(
                title: title,
                artist: artist,
                videoId: videoId,
                thumbnail: thumbnail,
              ),
            );
          }
          return;
        }

        if (node['playlistPanelVideoRenderer'] != null) {
          final p = node['playlistPanelVideoRenderer'] as Map<String, dynamic>;
          final videoId = p['videoId'] ?? '';
          final title = p['title']?['simpleText'] ?? '';
          String? thumbnail =
              (p['thumbnail']?['thumbnails'] as List?)?.last?['url'];
          if ((videoId as String).isNotEmpty) {
            tracks.add(
              Track(
                title: title ?? '',
                artist: '',
                videoId: videoId,
                thumbnail: thumbnail,
              ),
            );
          }
          return;
        }

        if (node['continuations'] != null && node['continuations'] is List) {
          for (var cont in node['continuations']) {
            if (cont is Map) {
              final token =
                  cont['nextContinuationData']?['continuation'] ??
                  cont['continuation'];
              if (token != null && continuationToken == null)
                continuationToken = token.toString();
            }
          }
        }

        if (node['nextContinuationData'] != null &&
            node['nextContinuationData']['continuation'] != null) {
          continuationToken ??= node['nextContinuationData']['continuation'];
        }

        node.forEach((k, v) {
          if (v != null) _collectFromNode(v);
        });
      }
    }

    try {
      final playlistUrl = 'https://www.youtube.com/playlist?list=$playlistId';
      final res = await http.get(
        Uri.parse(playlistUrl),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0 Safari/537.36',
          'Accept-Language': 'en-US,en;q=0.9',
        },
      );

      if (res.statusCode != 200) {
        print('Playlist page HTTP ${res.statusCode}');
        return tracks;
      }

      final body = res.body;

      final reg1 = RegExp(r'ytInitialData\s*=\s*({.*?});', dotAll: true);
      final reg2 = RegExp(
        r'window\["ytInitialData"\]\s*=\s*({.*?});',
        dotAll: true,
      );
      RegExpMatch? m = reg1.firstMatch(body) ?? reg2.firstMatch(body);

      if (m == null) {
        print(
          'Could not find ytInitialData in playlist HTML. YouTube changed layout?',
        );

        return tracks;
      }

      final jsonText = m.group(1)!;
      final data = jsonDecode(jsonText) as Map<String, dynamic>;

      _collectFromNode(data);
    } catch (e, st) {
      print('Failed to parse playlist HTML: $e');
      print(st);
      return tracks;
    }

    while ((tracks.length < limit) &&
        (continuationToken != null && continuationToken!.isNotEmpty)) {
      final token = continuationToken!;
      continuationToken = null;

      try {
        final ctx = client.baseContext();
        final body = {'context': ctx['context'], 'continuation': token};

        final contRes = await client.postYT('browse', body);

        _collectFromNode(contRes);
      } catch (e, st) {
        print('Continuation fetch failed: $e');
        print(st);
        break;
      }
    }

    final seen = <String>{};
    final out = <Track>[];
    for (var t in tracks) {
      if (!seen.contains(t.videoId)) {
        seen.add(t.videoId);
        out.add(t);
        if (out.length >= limit) break;
      }
    }

    return out;
  }
}
