import 'dart:async';
import 'package:flutter/material.dart';
import '../audora_music.dart';
import '../audio_manager.dart';
import 'playlist_screen.dart';

class HomeScreen extends StatefulWidget {
  final AudoraSearch search;
  final AudioManager audioManager;

  const HomeScreen({
    super.key,
    required this.search,
    required this.audioManager,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<Map<String, List<Track>>> allChartsFuture;
  final PageController _pageController = PageController(viewportFraction: 0.75);
  Timer? _autoScrollTimer;

  @override
  void initState() {
    super.initState();
    allChartsFuture = fetchAllCharts();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<Map<String, List<Track>>> fetchAllCharts() async {
    final charts = AudoraCharts(widget.search.client);

    final countryCodes = {
      'India': 'IN',
      'Japan': 'JP',
      'United Kingdom': 'UK',
      'Korea': 'KR',
    };

    final genres = ['Romance', 'Phonk', 'Sad', 'Lo-Fi'];

    try {
      final topFuture = charts.fetchGlobalTopCharts();

      final countryFutures = countryCodes.entries.map((entry) async {
        try {
          final tracks = await charts.fetchTrendingTracks(
            countryCode: entry.value,
          );
          return MapEntry(entry.key, tracks);
        } catch (e) {
          debugPrint('Error fetching ${entry.key}: $e');
          return MapEntry(entry.key, <Track>[]);
        }
      });

      final genreFutures = genres.map((entry) async {
        try {
          final tracks = await widget.search.fetchGenreSongs(entry);
          return MapEntry(entry, tracks);
        } catch (e) {
          debugPrint('Error fetching ${entry}: $e');
          return MapEntry(entry, <Track>[]);
        }
      });

      final results = await Future.wait([...countryFutures, ...genreFutures]);
      final mapData = Map.fromEntries(results);

      final topTracks = await topFuture;

      return {'Top Charts': topTracks, ...mapData};
    } catch (e) {
      debugPrint('Error fetching charts: $e');
      return {};
    }
  }

  void startAutoScroll(int itemCount) {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_pageController.hasClients && itemCount > 1) {
        final nextPage = _pageController.page!.round() + 1;
        _pageController.animateToPage(
          nextPage % itemCount,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _handleTapTrack(Track track, {List<Track>? queue}) async {
    final isPlaylist = (track.isPlaylist == true);
    final playlistId = track.playlistId;
    if (isPlaylist && playlistId != null && playlistId.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlaylistScreen(
            playlistId: playlistId,
            title: track.title,
            search: widget.search,
            playTrack: widget.audioManager.playTrack,
          ),
        ),
      );
      return;
    }

    await widget.audioManager.playTrack(track, queue: queue);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.86),
        elevation: 0,
        titleSpacing: 10,
        title: Row(
          children: [
            Image.asset('assets/icon/AudoraNoText.png', width: 34, height: 34),
            const SizedBox(width: 8),
            const Text(
              'AUDORA',
              style: TextStyle(
                fontSize: 22,
                letterSpacing: 1.6,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.circle, size: 6, color: Colors.white24),
          ],
        ),
      ),

      body: FutureBuilder<Map<String, List<Track>>>(
        future: allChartsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(color: Colors.white),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  "Failed to load charts: ${snapshot.error}",
                  style: const TextStyle(color: Colors.redAccent),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final chartData = snapshot.data ?? {};
          if (chartData.isEmpty) {
            return const Center(
              child: Text(
                "No charts available.",
                style: TextStyle(color: Colors.white54),
              ),
            );
          }

          final topCharts = chartData.remove('Top Charts');
          final others = chartData;

          if (topCharts != null && topCharts.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              startAutoScroll(topCharts.length);
            });
          }

          return SingleChildScrollView(
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
                  const SizedBox(height: 30),

                  if (topCharts != null && topCharts.isNotEmpty) ...[
                    const Text(
                      "Top Charts",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildTopCarousel(topCharts),
                    const SizedBox(height: 32),
                  ],

                  for (final entry in others.entries) ...[
                    Text(
                      entry.key,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildHorizontalList(entry.value),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopCarousel(List<Track> topCharts) {
    return SizedBox(
      height: 330,
      child: PageView.builder(
        controller: _pageController,
        itemCount: topCharts.length.clamp(0, 10),
        itemBuilder: (context, index) {
          final track = topCharts[index];
          final imageUrl = track.thumbnail;

          return AnimatedBuilder(
            animation: _pageController,
            builder: (context, child) {
              double value = 1.0;
              if (_pageController.position.haveDimensions) {
                value = _pageController.page! - index;
                value = (1 - (value.abs() * 0.25)).clamp(0.8, 1.0);
              }
              return Center(
                child: Transform.scale(scale: value, child: child),
              );
            },
            child: GestureDetector(
              onTap: () => _handleTapTrack(track, queue: topCharts),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (imageUrl != null)
                        Image.network(imageUrl, fit: BoxFit.cover)
                      else
                        Container(color: Colors.grey[850]),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.75),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Column(
                          children: [
                            Text(
                              track.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              track.artist ?? "Unknown Artist",
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHorizontalList(List<Track> tracks) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: tracks.length,
        itemBuilder: (context, index) {
          final track = tracks[index];
          final imageUrl = track.thumbnail;

          return GestureDetector(
            onTap: () => _handleTapTrack(track, queue: tracks),
            child: Container(
              width: 140,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.grey[900],
                image: imageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(imageUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
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
                    ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      height: 70,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                      ),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        track.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
