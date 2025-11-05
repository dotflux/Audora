import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import "../../utils/log.dart";

void main() {
  test('Fetch audio streams for mJ1N7-HyH1A', () async {
    final yt = YoutubeExplode();
    try {
      final manifest = await yt.videos.streams.getManifest(
        'mJ1N7-HyH1A',
        requireWatchPage: true,
        ytClients: [YoutubeApiClient.androidVr],
      );
      final audioOnly = manifest.audioOnly.sortByBitrate();
      expect(audioOnly, isNotEmpty);
      final low = audioOnly.first;
      final high = audioOnly.last;

      log.d(
        'LOW  -> bitrate: \'${low.bitrate}\' codec: \'${low.codec.mimeType}\' url: ${low.url}',
      );

      log.d(
        'HIGH -> bitrate: \'${high.bitrate}\' codec: \'${high.codec.mimeType}\' url: ${high.url}',
      );
    } finally {
      yt.close();
    }
  });
}
