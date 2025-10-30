import 'package:flutter/material.dart';
import '../audora_music.dart';
import '../audio_manager.dart';
import '../data/custom_playlists.dart';

class PlaylistScreen extends StatefulWidget {
  final String id;
  final String title;
  final bool isCustom;
  final AudioManager audioManager;
  final AudoraSearch search;
  final VoidCallback onBack;

  const PlaylistScreen({
    super.key,
    required this.id,
    required this.title,
    required this.isCustom,
    required this.audioManager,
    required this.search,
    required this.onBack,
  });

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  bool _isLoading = true;
  List<Track> _tracks = [];

  @override
  void initState() {
    super.initState();
    _loadPlaylist();
  }

  Future<void> _loadPlaylist() async {
    try {
      if (widget.isCustom) {
        final customTracks = CustomPlaylists.getTracks(widget.id);
        setState(() {
          _tracks = customTracks;
          _isLoading = false;
        });
      } else {
        final apiTracks = await widget.search.fetchPlaylist(widget.id);
        setState(() {
          _tracks = apiTracks;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        color: Colors.black,
        key: ValueKey(widget.id),
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: widget.onBack,
                ),
                backgroundColor: Colors.black,
                title: Text(
                  widget.title,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _tracks.isEmpty
                    ? const Center(
                        child: Text(
                          "No tracks here yet",
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _tracks.length,
                        itemBuilder: (context, i) {
                          final track = _tracks[i];
                          return ListTile(
                            onTap: () => widget.audioManager.playTrack(
                              track,
                              queue: _tracks,
                            ),
                            leading: ClipRRect(
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
                                      color: Colors.white24,
                                      child: const Icon(
                                        Icons.music_note,
                                        color: Colors.white54,
                                      ),
                                    ),
                            ),
                            title: Text(
                              track.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              track.artist,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 13,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
