import 'package:flutter/material.dart';
import '../audora_music.dart';
import '../audio_manager.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class SearchScreen extends StatefulWidget {
  final AudioManager audioManager;

  const SearchScreen({super.key, required this.audioManager});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  late final AudoraSearch _search;
  List<Track> _tracks = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _search = AudoraSearch(widget.audioManager.player.client);
  }

  Future<void> _searchTracks(String query) async {
    if (query.isEmpty) return;
    setState(() {
      _isLoading = true;
      _tracks = [];
    });

    try {
      final visitorData = await widget.audioManager.player.client
          .getVisitorData();
      final results = await _search.search(query, visitorData: visitorData);
      setState(() {
        _tracks = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Search failed: $e')));
    }
  }

  Future<File?> _getCachedAudio(String videoId) async {
    final tempDir = await getTemporaryDirectory();
    for (var ext in ['m4a', 'mp3', 'mp4']) {
      final file = File('${tempDir.path}/$videoId.$ext');
      if (file.existsSync()) return file;
    }
    return null;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          const SizedBox(height: 10),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Search songs, artists...",
                  hintStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: const Color(0xFF121212),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.search, color: Colors.white70),
                ),
                onSubmitted: _searchTracks,
              ),
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(
                color: Color(0xFF0A84FF),
                backgroundColor: Colors.transparent,
                minHeight: 2,
              ),
            ),
          const SizedBox(height: 10),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _tracks.isEmpty && !_isLoading
                  ? const Center(
                      child: Text(
                        "No results yet. Try searching something.",
                        style: TextStyle(color: Colors.white38, fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      itemCount: _tracks.length,
                      itemBuilder: (context, index) {
                        final track = _tracks[index];
                        return GestureDetector(
                          onTap: () async {
                            await widget.audioManager.playTrack(
                              track,
                              queue: _tracks,
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: track.thumbnail != null
                                      ? Image.network(
                                          track.thumbnail!,
                                          width: 55,
                                          height: 55,
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
                                          width: 55,
                                          height: 55,
                                          color: Colors.white.withOpacity(0.05),
                                          child: const Icon(
                                            Icons.music_note,
                                            color: Colors.white54,
                                            size: 30,
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        track.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        track.artist,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
