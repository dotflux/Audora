import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import '../audora_music.dart';
import '../audio_manager.dart';
import 'add_to_playlist.dart';

class TrackOptionsMenu extends StatelessWidget {
  final Track track;
  final AudioManager audioManager;
  final MediaItem? mediaItem;
  final bool showAddToPlaylist;

  const TrackOptionsMenu({
    super.key,
    required this.track,
    required this.audioManager,
    this.mediaItem,
    this.showAddToPlaylist = true,
  });

  static void show({
    required BuildContext context,
    required Track track,
    required AudioManager audioManager,
    MediaItem? mediaItem,
    bool showAddToPlaylist = true,
    MediaItem? currentMediaItem,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (context) {
        return SafeArea(
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF181818),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                TrackOptionsMenu(
                  track: track,
                  audioManager: audioManager,
                  mediaItem: mediaItem,
                  showAddToPlaylist: showAddToPlaylist,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddToPlaylist(BuildContext context) {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AddToPlaylistDialog(track: track),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showAddToPlaylist)
          ListTile(
            leading: const Icon(Icons.playlist_add, color: Colors.white70),
            title: const Text(
              'Add to Playlist',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () => _showAddToPlaylist(context),
          ),
        ListTile(
          leading: const Icon(Icons.queue_music, color: Colors.white70),
          title: const Text(
            'Play Next',
            style: TextStyle(color: Colors.white),
          ),
          onTap: () {
            audioManager.playNext(track);
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('"${track.title}" will play next'),
                duration: const Duration(seconds: 2),
                backgroundColor: Colors.green,
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.add_circle_outline, color: Colors.white70),
          title: const Text(
            'Add to Queue',
            style: TextStyle(color: Colors.white),
          ),
          onTap: () {
            audioManager.addToQueue(track);
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('"${track.title}" added to queue'),
                duration: const Duration(seconds: 2),
                backgroundColor: Colors.blue,
              ),
            );
          },
        ),
      ],
    );
  }
}

