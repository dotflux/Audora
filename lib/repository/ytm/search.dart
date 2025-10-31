import 'client.dart';
import 'track.dart';
import 'params.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../utils/log.dart';

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
      log.d('No tabs found in response');
      return [];
    }

    final sections =
        tabs[0]?['tabRenderer']?['content']?['sectionListRenderer']?['contents']
            as List?;
    if (sections == null) {
      log.d('No sections found in first tab');
      return [];
    }

    final tracks = <Track>[];

    String? findPlaylistId(dynamic node) {
      if (node == null) return null;
      if (node is Map) {
        if (node.containsKey('playlistId') && node['playlistId'] is String) {
          final pid = node['playlistId'] as String;
          if (pid.isNotEmpty) return pid;
        }

        if (node.containsKey('browseId') && node['browseId'] is String) {
          final b = (node['browseId'] as String).toString();
          if (b.startsWith('PL') || b.startsWith('VL') || b.startsWith('RD')) {
            return b;
          }
        }

        for (final v in node.values) {
          final found = findPlaylistId(v);
          if (found != null) return found;
        }
      } else if (node is List) {
        for (final e in node) {
          final found = findPlaylistId(e);
          if (found != null) return found;
        }
      }
      return null;
    }

    String? pickBestThumbnail(dynamic thumbsNode) {
      try {
        final thumbs = thumbsNode as List?;
        if (thumbs == null || thumbs.isEmpty) return null;

        thumbs.sort((a, b) {
          final aw = (a?['width'] ?? 0) as int;
          final bw = (b?['width'] ?? 0) as int;
          return bw.compareTo(aw);
        });
        final url = thumbs.first['url']?.toString();
        if (url != null) {
          return url.replaceAll(RegExp(r'=w\d+-h\d+'), '=w1080-h1080');
        }
      } catch (_) {}
      return null;
    }

    final seenTitles = <String>{};

    for (var section in sections) {
      List? items;

      if (section['musicShelfRenderer'] != null) {
        items = section['musicShelfRenderer']['contents'] as List?;
      } else if (section['musicCardShelfRenderer'] != null) {
        items = section['musicCardShelfRenderer']['contents'] as List?;
      } else {
        continue;
      }

      if (items == null) continue;

      for (var item in items) {
        final renderer = item['musicResponsiveListItemRenderer'] ?? item;
        if (renderer == null) {
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
            title = (titleRuns.map((r) => r['text'] ?? '').join()).toString();
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

        String videoId = '';
        try {
          videoId =
              renderer['navigationEndpoint']?['watchEndpoint']?['videoId'] ??
              renderer['overlay']?['musicItemThumbnailOverlayRenderer']?['content']?['musicPlayButtonRenderer']?['playNavigationEndpoint']?['watchEndpoint']?['videoId'] ??
              '';
        } catch (_) {
          videoId = '';
        }

        String? thumbnail;
        try {
          final thumbsNode =
              renderer['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'];
          thumbnail = pickBestThumbnail(thumbsNode);
        } catch (_) {
          thumbnail = null;
        }

        final playlistId = findPlaylistId(renderer);

        final isPlaylist =
            playlistId != null && playlistId.isNotEmpty && (videoId == '');

        final normalizedTitle = (title.isNotEmpty ? title : 'Unknown Title')
            .trim()
            .toLowerCase();

        if (seenTitles.contains(normalizedTitle)) {
          continue;
        }

        if (isPlaylist) {
          try {
            final preview = await fetchPlaylist(playlistId, limit: 1);
            if (preview.isEmpty) {
              continue;
            }
          } catch (e) {
            log.d('Playlist probe failed for $playlistId: $e');
            continue;
          }
        }

        if ((videoId.isNotEmpty) || isPlaylist) {
          final effectiveTitle = title.isNotEmpty ? title : 'Unknown Title';
          tracks.add(
            Track(
              title: effectiveTitle,
              artist: artist,
              videoId: videoId,
              thumbnail: thumbnail,
              playlistId: playlistId,
              isPlaylist: isPlaylist,
            ),
          );

          seenTitles.add(normalizedTitle);
        }

        if (tracks.length >= limit) break;
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
        for (final e in node) {
          _collectFromNode(e);
        }
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
        log.d('Playlist page HTTP ${res.statusCode}');
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
        log.d(
          'Could not find ytInitialData in playlist HTML. YouTube changed layout?',
        );

        return tracks;
      }

      final jsonText = m.group(1)!;
      final data = jsonDecode(jsonText) as Map<String, dynamic>;

      _collectFromNode(data);
    } catch (e, st) {
      log.d('Failed to parse playlist HTML: $e');
      log.d(st);
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
        log.d('Continuation fetch failed: $e');
        log.d(st);
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

  Future<List<Track>> fetchGenreSongs(String genre, {int limit = 20}) async {
    final query = '$genre songs';
    log.d('🎧 fetching genre chart for "$query"...');
    try {
      final tracks = await search(query, filter: Params.songs, limit: limit);
      return tracks;
    } catch (e) {
      log.d('⚠️ failed to fetch genre chart for $genre: $e');
      return [];
    }
  }
}
