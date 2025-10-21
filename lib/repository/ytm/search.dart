import 'client.dart';
import 'track.dart';
import 'params.dart';

class AudoraSearch {
  final AudoraClient client;

  AudoraSearch(this.client);

  Future<List<Track>> search(
    String query, {
    String filter = Params.songs,
    int limit = 10,
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
        String? thumbnail =
            renderer['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails']?[0]?['url'];

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
}
