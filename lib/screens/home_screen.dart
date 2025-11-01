import 'dart:async';
import 'package:flutter/material.dart';
import '../audora_music.dart';
import '../audio_manager.dart';
import '/data/recently_played.dart';

class HomeScreen extends StatefulWidget {
  final AudoraSearch search;
  final AudioManager audioManager;
  final void Function({
    required String id,
    required String title,
    required bool isCustom,
  })
  openPlaylist;

  const HomeScreen({
    super.key,
    required this.search,
    required this.audioManager,
    required this.openPlaylist,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static Map<String, List<Track>>? _cachedCharts;
  static DateTime? _lastFetchTime;

  late Future<Map<String, List<Track>>> allChartsFuture;
  late Future<List<Track>> recentlyPlayedFuture;
  final PageController _pageController = PageController(viewportFraction: 0.75);
  Timer? _autoScrollTimer;
  StreamSubscription? _recentlyPlayedSub;

  @override
  void initState() {
    super.initState();

    if (_cachedCharts != null &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) <
            const Duration(minutes: 10)) {
      allChartsFuture = Future.value(_cachedCharts);
    } else {
      allChartsFuture = _fetchAndCacheCharts(forceRefresh: true);
    }

    recentlyPlayedFuture = RecentlyPlayed.getTracks();

    _recentlyPlayedSub = RecentlyPlayed.onChange.listen((_) {
      setState(() {
        recentlyPlayedFuture = RecentlyPlayed.getTracks();
      });
    });
  }

  @override
  void dispose() {
    _recentlyPlayedSub?.cancel();
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<Map<String, List<Track>>> _fetchAndCacheCharts({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _cachedCharts != null &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) <
            const Duration(minutes: 10)) {
      return _cachedCharts!;
    }

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
        } catch (_) {
          return MapEntry(entry.key, <Track>[]);
        }
      });

      final genreFutures = genres.map((entry) async {
        try {
          final tracks = await widget.search.fetchGenreSongs(entry);
          return MapEntry(entry, tracks);
        } catch (_) {
          return MapEntry(entry, <Track>[]);
        }
      });

      final results = await Future.wait([...countryFutures, ...genreFutures]);
      final topTracks = await topFuture;

      final data = {'Top Charts': topTracks, ...Map.fromEntries(results)};
      _cachedCharts = data;
      _lastFetchTime = DateTime.now();

      return data;
    } catch (e) {
      debugPrint("⚠️ Chart fetch error: $e");
      return _cachedCharts ?? {};
    }
  }

  void _startAutoScroll(int count) {
    _autoScrollTimer?.cancel();
    if (count <= 1) return;

    _autoScrollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_pageController.hasClients) {
        final next = (_pageController.page?.round() ?? 0) + 1;
        _pageController.animateToPage(
          next % count,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _handleTapTrack(Track track, {List<Track>? queue}) async {
    final isPlaylist = (track.isPlaylist == true);
    if (isPlaylist && track.playlistId?.isNotEmpty == true) {
      widget.openPlaylist(
        id: track.playlistId!,
        title: track.title,
        isCustom: false,
      );
      return;
    }

    await widget.audioManager.playTrack(
      track,
      queue: queue,
      fetchRelated: true,
    );

    setState(() {
      recentlyPlayedFuture = RecentlyPlayed.getTracks();
    });
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
          final charts = snapshot.data ?? _cachedCharts ?? {};
          if (snapshot.connectionState == ConnectionState.waiting &&
              charts.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          if (charts.isEmpty) {
            return const Center(
              child: Text(
                "No charts available.",
                style: TextStyle(color: Colors.white54),
              ),
            );
          }

          final top = charts['Top Charts'] ?? [];
          final others = Map.of(charts)..remove('Top Charts');

          if (top.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _startAutoScroll(top.length),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                allChartsFuture = _fetchAndCacheCharts(forceRefresh: true);
              });
            },
            color: Colors.white,
            backgroundColor: Colors.black,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
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
                    _buildRecentlyPlayed(),
                    const SizedBox(height: 30),

                    if (top.isNotEmpty) ...[
                      const Text(
                        "Top Charts",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildTopCarousel(top),
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
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentlyPlayed() {
    return FutureBuilder<List<Track>>(
      future: recentlyPlayedFuture,
      builder: (context, snapshot) {
        final tracks = snapshot.data ?? [];
        if (snapshot.connectionState == ConnectionState.waiting &&
            tracks.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }
        if (tracks.isEmpty) {
          return const Text(
            "No recently played tracks yet.",
            style: TextStyle(color: Colors.white54),
          );
        }

        return SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: tracks.length,
            itemBuilder: (context, i) {
              final track = tracks[i];
              return GestureDetector(
                onTap: () => _handleTapTrack(track),
                child: Container(
                  width: 140,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    image: track.thumbnail != null
                        ? DecorationImage(
                            image: NetworkImage(track.thumbnail!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(16),
                        ),
                      ),
                      child: Text(
                        track.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTopCarousel(List<Track> top) {
    return SizedBox(
      height: 330,
      child: PageView.builder(
        controller: _pageController,
        itemCount: top.length.clamp(0, 10),
        itemBuilder: (context, index) {
          final track = top[index];
          return GestureDetector(
            onTap: () => _handleTapTrack(track),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (track.thumbnail != null)
                      Image.network(track.thumbnail!, fit: BoxFit.cover)
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
        itemBuilder: (context, i) {
          final track = tracks[i];
          return GestureDetector(
            onTap: () => _handleTapTrack(track),
            child: Container(
              width: 140,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.grey[900],
                image: track.thumbnail != null
                    ? DecorationImage(
                        image: NetworkImage(track.thumbnail!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  alignment: Alignment.center,
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
            ),
          );
        },
      ),
    );
  }
}
