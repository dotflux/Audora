import 'client.dart';
import 'track.dart';
import 'params.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../utils/log.dart';

class AudoraSearch {
  final AudoraClient client;

  AudoraSearch(this.client);

  Future<({List<Track> tracks, String? continuation})> searchPaged(
    String query, {
    String filter = Params.songs,
    int pageSize = 20,
    String? visitorData,
  }) async {
    final body = Map<String, dynamic>.from(
      client.baseContext(visitorData: visitorData),
    );
    body['query'] = query;
    body['params'] = filter;

    final res = await client.post('search', body);
    return _parseSearchResponse(res, limit: pageSize);
  }

  Future<({List<Track> tracks, String? continuation})> searchNext(
    String continuation, {
    int pageSize = 20,
    String? visitorData,
  }) async {
    final ctx = client.baseContext(visitorData: visitorData);
    final body = {'context': ctx['context'], 'continuation': continuation};
    final res = await client.post('search', body);
    return _parseSearchResponse(res, limit: pageSize);
  }

  Future<List<Track>> search(
    String query, {
    String filter = Params.songs,
    int limit = 20,
    String? visitorData,
  }) async {
    final page = await searchPaged(
      query,
      filter: filter,
      pageSize: limit,
      visitorData: visitorData,
    );
    return page.tracks;
  }

  ({List<Track> tracks, String? continuation}) _parseSearchResponse(
    Map<String, dynamic> res, {
    required int limit,
  }) {
    final tracks = <Track>[];

    final List<List> candidateSections = [];
    try {
      final tabs =
          res['contents']?['tabbedSearchResultsRenderer']?['tabs'] as List?;
      if (tabs != null && tabs.isNotEmpty) {
        final list =
            tabs[0]?['tabRenderer']?['content']?['sectionListRenderer']?['contents']
                as List?;
        if (list != null) candidateSections.add(list);
      }
    } catch (_) {}
    try {
      final list =
          res['continuationContents']?['sectionListContinuation']?['contents']
              as List?;
      if (list != null) candidateSections.add(list);
    } catch (_) {}
    try {
      final list =
          res['continuationContents']?['musicShelfContinuation']?['contents']
              as List?;
      if (list != null) candidateSections.add(list);
    } catch (_) {}
    try {
      final commands = res['onResponseReceivedCommands'] as List?;
      if (commands != null) {
        for (final cmd in commands) {
          final items =
              cmd?['appendContinuationItemsAction']?['continuationItems']
                  as List?;
          if (items != null) candidateSections.add(items);
        }
      }
    } catch (_) {}
    if (candidateSections.isEmpty) {
      log.d('No sections found in search response');
      return (tracks: const <Track>[], continuation: null);
    }

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
    String? nextContinuation;

    String? _findContinuationInNode(dynamic node) {
      try {
        if (node is Map) {
          final ncd = node['nextContinuationData']?['continuation'];
          if (ncd is String && ncd.isNotEmpty) return ncd;
          final token =
              node['continuationEndpoint']?['continuationCommand']?['token'];
          if (token is String && token.isNotEmpty) return token;
          for (final v in node.values) {
            final t = _findContinuationInNode(v);
            if (t != null) return t;
          }
        } else if (node is List) {
          for (final v in node) {
            final t = _findContinuationInNode(v);
            if (t != null) return t;
          }
        }
      } catch (_) {}
      return null;
    }

    for (final sections in candidateSections) {
      for (var section in sections) {
        List? items;

        if (section['musicShelfRenderer'] != null) {
          items = section['musicShelfRenderer']['contents'] as List?;

          try {
            final conts =
                section['musicShelfRenderer']['continuations'] as List?;
            if (conts != null && conts.isNotEmpty) {
              nextContinuation = conts
                  .first['nextContinuationData']?['continuation']
                  ?.toString();
            }
          } catch (_) {}
        } else if (section['musicShelfContinuation'] != null) {
          items = section['musicShelfContinuation']['contents'] as List?;
          nextContinuation ??= _findContinuationInNode(
            section['musicShelfContinuation'],
          );
        } else if (section['musicCardShelfRenderer'] != null) {
          items = section['musicCardShelfRenderer']['contents'] as List?;
        } else if (section['musicResponsiveListItemRenderer'] != null) {
          items = [section];
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
            final movingThumbs =
                renderer['richThumbnail']?['movingThumbnailRenderer']?['movingThumbnailDetails']?['thumbnails'] ??
                renderer['richThumbnail']?['richThumbnailRenderer']?['movingThumbnailRenderer']?['movingThumbnailDetails']?['thumbnails'];
            final movingUrl = pickBestThumbnail(movingThumbs);
            if (movingUrl != null && movingUrl.isNotEmpty) {
              thumbnail = movingUrl;
            }
          } catch (_) {}
          try {
            if (thumbnail == null) {
              final thumbsNode =
                  renderer['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'];
              thumbnail = pickBestThumbnail(thumbsNode);
            }
          } catch (_) {
            thumbnail = null;
          }

          final playlistId = findPlaylistId(renderer);
          final isPlaylist =
              playlistId != null && playlistId.isNotEmpty && (videoId == '');

          String? musicVideoType;
          try {
            musicVideoType =
                renderer['navigationEndpoint']?['watchEndpoint']?['watchEndpointMusicSupportedConfigs']?['watchEndpointMusicConfig']?['musicVideoType']
                    ?.toString();
          } catch (_) {
            musicVideoType = null;
          }

          if (musicVideoType != null &&
              musicVideoType.isNotEmpty &&
              videoId.isNotEmpty) {
            if (thumbnail == null || !thumbnail.contains('an_webp')) {
              thumbnail = 'https://i.ytimg.com/vi/' + videoId + '/hq720.jpg';
            }
          }

          final normalizedTitle = (title.isNotEmpty ? title : 'Unknown Title')
              .trim()
              .toLowerCase();

          if (seenTitles.contains(normalizedTitle)) {
            continue;
          }

          if (videoId.isNotEmpty && !isPlaylist) {
            final effectiveTitle = title.isNotEmpty ? title : 'Unknown Title';
            tracks.add(
              Track(
                title: effectiveTitle,
                artist: artist,
                videoId: videoId,
                thumbnail: thumbnail,

                playlistId: null,
                isPlaylist: false,
              ),
            );

            seenTitles.add(normalizedTitle);
          }

          if (tracks.length >= limit) break;
        }

        if (tracks.length >= limit) break;
      }
    }

    return (
      tracks: tracks.take(limit).toList(),
      continuation: nextContinuation,
    );
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

  Future<List<Track>> getRelatedSongs(
    String videoId, {
    String? visitorData,
  }) async {
    try {
      log.d('🎵 Fetching related songs for videoId: $videoId');

      final vData = visitorData ?? await client.getVisitorData();

      final body1 = Map<String, dynamic>.from(
        client.baseContext(visitorData: vData),
      );
      body1['isAudioOnly'] = true;
      body1['videoId'] = videoId;
      body1['enablePersistentPlaylistPanel'] = true;
      body1['tunerSettingValue'] = 'AUTOMIX_SETTING_NORMAL';
      body1['params'] = 'wAEB';

      final res1 = await client.post('next', body1, visitorData: vData);

      dynamic nav(Map data, List path) {
        dynamic current = data;
        for (final key in path) {
          if (current is Map) {
            current = current[key];
          } else if (current is List && key is int && key < current.length) {
            current = current[key];
          } else {
            return null;
          }
        }
        return current;
      }

      final playlistId = nav(res1, [
        'contents',
        'singleColumnMusicWatchNextResultsRenderer',
        'tabbedRenderer',
        'watchNextTabbedResultsRenderer',
        'tabs',
        0,
        'tabRenderer',
        'content',
        'musicQueueRenderer',
        'content',
        'playlistPanelRenderer',
        'contents',
        1,
        'automixPreviewVideoRenderer',
        'content',
        'automixPlaylistVideoRenderer',
        'navigationEndpoint',
        'watchPlaylistEndpoint',
        'playlistId',
      ])?.toString();

      if (playlistId == null || playlistId.isEmpty) {
        log.d('⚠️ No automix playlist found for videoId: $videoId');
        return [];
      }

      log.d('✅ Found automix playlistId: $playlistId');

      final body2 = Map<String, dynamic>.from(
        client.baseContext(visitorData: vData),
      );
      body2['isAudioOnly'] = true;
      body2['videoId'] = videoId;
      body2['playlistId'] = playlistId;
      body2['enablePersistentPlaylistPanel'] = true;
      body2['tunerSettingValue'] = 'AUTOMIX_SETTING_NORMAL';
      body2['params'] = 'wAEB';

      final res2 = await client.post('next', body2, visitorData: vData);

      final items =
          (nav(res2, [
                'contents',
                'singleColumnMusicWatchNextResultsRenderer',
                'tabbedRenderer',
                'watchNextTabbedResultsRenderer',
                'tabs',
                0,
                'tabRenderer',
                'content',
                'musicQueueRenderer',
                'content',
                'playlistPanelRenderer',
                'contents',
              ])
              as List?) ??
          [];

      final List<Track> results = [];

      for (final item in items) {
        try {
          final itemMap = item as Map;
          final renderer = itemMap['playlistPanelVideoRenderer'] as Map?;
          if (renderer == null) continue;

          final title =
              nav(renderer, ['title', 'runs', 0, 'text'])?.toString() ?? '';
          final vidId = nav(renderer, ['videoId'])?.toString();
          if (vidId == null || vidId.isEmpty) continue;

          String image = '';
          try {
            final thumbs = nav(renderer, ['thumbnail', 'thumbnails']) as List?;
            if (thumbs != null && thumbs.isNotEmpty) {
              image = thumbs.last['url']?.toString() ?? '';
              image = image.replaceAll(RegExp(r'=w\d+-h\d+'), '=w1080-h1080');
            }
          } catch (_) {
            image = '';
          }
          final duration =
              nav(renderer, ['lengthText', 'runs', 0, 'text'])?.toString() ??
              '';

          final subtitleList =
              (nav(renderer, ['longBylineText', 'runs']) as List?) ?? [];
          String artists = '';
          String album = '';
          int count = 0;

          for (final element in subtitleList) {
            final elMap = element as Map;
            if (elMap['text']?.toString().trim() == '•') {
              count++;
            } else {
              if (count == 0) {
                artists += elMap['text']?.toString() ?? '';
              } else if (count == 1 && subtitleList.length > 2) {
                album += elMap['text']?.toString() ?? '';
              }
            }
          }

          if (album.contains('views')) album = '';

          int? durationSec;
          if (duration.isNotEmpty) {
            try {
              final parts = duration.split(':');
              if (parts.length == 2) {
                durationSec = int.parse(parts[0]) * 60 + int.parse(parts[1]);
              } else if (parts.length == 3) {
                durationSec =
                    int.parse(parts[0]) * 3600 +
                    int.parse(parts[1]) * 60 +
                    int.parse(parts[2]);
              }
            } catch (_) {}
          }

          results.add(
            Track(
              videoId: vidId,
              title: title,
              artist: artists,
              thumbnail: image.isNotEmpty ? image : null,
              durationSec: durationSec,
            ),
          );
        } catch (e) {
          log.d('⚠️ Error parsing related song item: $e');
          continue;
        }
      }

      log.d('✅ Found ${results.length} related songs');
      return results;
    } catch (e, st) {
      log.d('⚠️ Failed to fetch related songs for $videoId: $e');
      log.d(st);
      return [];
    }
  }
}
