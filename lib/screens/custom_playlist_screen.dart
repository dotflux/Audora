import 'package:flutter/material.dart';
import '../audora_music.dart';
import '../data/custom_playlists.dart';

class CustomPlaylistScreen extends StatefulWidget {
  final String playlistName;
  final Future<void> Function(Track, {List<Track>? queue}) playTrack;
  final VoidCallback? onBack;

  const CustomPlaylistScreen({
    super.key,
    required this.playlistName,
    required this.playTrack,
    this.onBack,
  });

  @override
  State<CustomPlaylistScreen> createState() => _CustomPlaylistScreenState();
}

class _CustomPlaylistScreenState extends State<CustomPlaylistScreen> {
  List<Track> _tracks = [];

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  void _loadTracks() {
    setState(() {
      _tracks = CustomPlaylists.getTracks(widget.playlistName);
    });
  }

  Future<void> _removeTrack(Track track) async {
    await CustomPlaylists.removeTrack(widget.playlistName, track.videoId);
    _loadTracks();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Column(
        children: [
          AppBar(
            backgroundColor: Colors.black,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: widget.onBack,
            ),
            title: Text(
              widget.playlistName,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          Expanded(
            child: _tracks.isEmpty
                ? const Center(
                    child: Text(
                      "No songs added yet.",
                      style: TextStyle(color: Colors.white54, fontSize: 15),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemCount: _tracks.length,
                    itemBuilder: (context, index) {
                      final track = _tracks[index];
                      return Dismissible(
                        key: ValueKey(track.videoId),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) => _removeTrack(track),
                        background: Container(
                          color: Colors.redAccent,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        child: GestureDetector(
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
                                          color: Colors.white.withOpacity(0.15),
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
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
