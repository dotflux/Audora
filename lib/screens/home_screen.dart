import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import '../audora_music.dart';
import 'playlist_screen.dart';
import '../audio_manager.dart';

class HomeScreen extends StatelessWidget {
  final AudoraSearch search;
  final AudioManager audioManager;

  HomeScreen({super.key, required this.search, required this.audioManager});

  final Map<String, List<Map<String, String>>> playlistsByCategory = {
    'Top Charts': [
      {
        'title': 'Top 50 Global Spotify',
        'id': 'PLgzTt0k8mXzEk586ze4BjvDXR7c-TUSnx',
      },
      {
        'title': 'Top 100 songs India',
        'id': 'PL4fGSI1pDJn4pTWyM3t61lOyZ6_4jcNOw',
      },
      {'title': 'Top Songs 2025', 'id': 'PLDIoUOhQQPlXr63I_vwF9GD8sAKh77dWU'},
    ],
    'Billboard': [
      {
        'title': 'Billboard Global hot 200',
        'id': 'PLHESV6Nt5Fmw9L47EKqxyt-u0XA3sHFTm',
      },
      {
        'title': 'Billboard Japan hot 100',
        'id': 'PL5DUky-xy5qAUEA9R4pNlUa5esVCzvZXs',
      },
    ],
    'KPOP': [
      {'title': 'KPOP 2025', 'id': 'PLOHoVaTp8R7dfrJW5pumS0iD_dhlXKv17'},
    ],
    'Phonk': [
      {'title': 'PHONK 2025', 'id': 'PLPVMrZzinX9TXO_7RERwBkNCCY5LLUap0'},
    ],
    'Bollywood': [
      {
        'title': 'Best iconic bollywood songs',
        'id': 'PLedC6ZKrrIHikOi1oTaCfCYyjd47WX8cn',
      },
      {
        'title': 'Famous punjabi songs',
        'id': 'PL-oM5qTjmK2vxdTsj2Xghu5fjxhtuMaxo',
      },
    ],
  };

  Future<List<Color>> getPaletteColors(String? imageUrl) async {
    if (imageUrl == null) return [];
    final palette = await PaletteGenerator.fromImageProvider(
      NetworkImage(imageUrl),
      maximumColorCount: 10,
    );

    final colors = <Color>[];
    if (palette.vibrantColor != null) colors.add(palette.vibrantColor!.color);
    if (palette.lightVibrantColor != null)
      colors.add(palette.lightVibrantColor!.color);
    if (palette.mutedColor != null) colors.add(palette.mutedColor!.color);
    if (palette.lightMutedColor != null)
      colors.add(palette.lightMutedColor!.color);

    return colors;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        titleSpacing: 0,
        title: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/icon/AudoraNoText.png',
                      width: 32,
                      height: 32,
                    ),
                    const SizedBox(width: 6),
                  ],
                ),
              ),
            ),

            Center(
              child: Text(
                'Home',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),

      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Recently Played",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 160,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 5,
                  itemBuilder: (context, index) {
                    return Container(
                      width: 140,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.grey[850],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.music_note,
                          color: Colors.white38,
                          size: 40,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              for (final category in playlistsByCategory.entries) ...[
                Text(
                  category.key,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: category.value.length,
                    itemBuilder: (context, index) {
                      final playlist = category.value[index];
                      return FutureBuilder<List<Track>>(
                        future: search.fetchPlaylist(playlist['id']!),
                        builder: (context, snapshot) {
                          String? imageUrl;
                          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                            imageUrl = snapshot.data![0].thumbnail;
                          }

                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PlaylistScreen(
                                    playlistId: playlist['id']!,
                                    title: playlist['title']!,
                                    search: search,
                                    playTrack: audioManager.playTrack,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              width: 140,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                image: imageUrl != null
                                    ? DecorationImage(
                                        image: NetworkImage(imageUrl),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                                color: Colors.grey[900],
                              ),
                              child: Stack(
                                children: [
                                  if (imageUrl != null)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: Image.network(
                                        imageUrl,
                                        width: double.infinity,
                                        height: double.infinity,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  else
                                    Container(
                                      width: double.infinity,
                                      height: double.infinity,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[900],
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.music_note,
                                          color: Colors.white38,
                                          size: 40,
                                        ),
                                      ),
                                    ),

                                  Align(
                                    alignment: Alignment.bottomCenter,
                                    child: FutureBuilder<List<Color>>(
                                      future: getPaletteColors(imageUrl),
                                      builder: (context, paletteSnapshot) {
                                        Color overlayColor = Colors.black
                                            .withAlpha((0.5 * 255).round());
                                        if (paletteSnapshot.hasData &&
                                            paletteSnapshot.data!.isNotEmpty) {
                                          overlayColor = paletteSnapshot.data!
                                              .reduce(
                                                (a, b) =>
                                                    a.computeLuminance() >
                                                        b.computeLuminance()
                                                    ? a
                                                    : b,
                                              )
                                              .withAlpha((0.5 * 255).round());
                                        }

                                        return Container(
                                          height: 70,
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            color: overlayColor,
                                            borderRadius:
                                                const BorderRadius.only(
                                                  bottomLeft: Radius.circular(
                                                    16,
                                                  ),
                                                  bottomRight: Radius.circular(
                                                    16,
                                                  ),
                                                ),
                                          ),
                                          alignment: Alignment.center,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                          child: Text(
                                            playlist['title']!,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
