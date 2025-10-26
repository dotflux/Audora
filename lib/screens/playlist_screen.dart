import 'package:flutter/material.dart';
import '../audora_music.dart';
import '../audio_manager.dart';

class PlaylistScreen extends StatefulWidget {
  final String playlistId;
  final String title;
  final AudoraSearch search;
  final Future<void> Function(Track, {List<Track>? queue}) playTrack;

  const PlaylistScreen({
    super.key,
    required this.playlistId,
    required this.title,
    required this.search,
    required this.playTrack,
  });

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  List<Track> _tracks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlaylist();
  }

  Future<void> _loadPlaylist() async {
    try {
      final tracks = await widget.search.fetchPlaylist(widget.playlistId);
      setState(() {
        _tracks = tracks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load playlist: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.black,
        title: Text(widget.title, style: TextStyle(color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _tracks.length,
              itemBuilder: (context, index) {
                final track = _tracks[index];
                return GestureDetector(
                  onTap: () => widget.playTrack(track, queue: _tracks),
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
                                  color: Colors.white.withAlpha(
                                    (0.5 * 255).round(),
                                  ),
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
                            crossAxisAlignment: CrossAxisAlignment.start,
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
    );
  }
}
