import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

class MiniPlayer extends StatelessWidget {
  final AudioPlayer player;
  final MediaItem? mediaItem;

  const MiniPlayer({super.key, required this.player, this.mediaItem});

  @override
  Widget build(BuildContext context) {
    if (mediaItem == null) return const SizedBox.shrink();

    return Container(
      color: Colors.grey[900],
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          if (mediaItem!.artUri != null)
            Image.network(
              mediaItem!.artUri.toString(),
              width: 50,
              height: 50,
              fit: BoxFit.cover,
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mediaItem!.title,
                  style: const TextStyle(color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  mediaItem!.artist ?? '',
                  style: const TextStyle(color: Colors.white70),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          StreamBuilder<PlayerState>(
            stream: player.playerStateStream,
            builder: (context, snapshot) {
              final isPlaying = snapshot.data?.playing ?? false;
              return IconButton(
                icon: Icon(
                  isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                ),
                onPressed: () {
                  if (isPlaying) {
                    player.pause();
                  } else {
                    player.play();
                  }
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
