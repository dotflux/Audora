import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../screens/player_screen.dart';

class MiniPlayer extends StatelessWidget {
  final AudioPlayer player;
  final MediaItem? mediaItem;
  final ValueNotifier<bool>? isLoadingNotifier;
  final ValueNotifier<MediaItem?> currentTrackNotifier;

  final VoidCallback? onNext;
  final VoidCallback? onPrevious;

  const MiniPlayer({
    super.key,
    required this.player,
    this.mediaItem,
    this.isLoadingNotifier,
    required this.currentTrackNotifier,
    this.onNext,
    this.onPrevious,
  });

  @override
  Widget build(BuildContext context) {
    if (mediaItem == null) return const SizedBox.shrink();

    return ValueListenableBuilder<bool>(
      valueListenable: isLoadingNotifier ?? ValueNotifier(false),
      builder: (context, isLoading, _) {
        return GestureDetector(
          onTap: () {
            if (!isLoading && mediaItem != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PlayerScreen(
                    player: player,
                    mediaItem: mediaItem!,
                    currentTrackNotifier: currentTrackNotifier,
                    isLoadingNotifier: isLoadingNotifier,
                    onNext: onNext,
                    onPrevious: onPrevious,
                  ),
                ),
              );
            }
          },
          child: Container(
            margin: const EdgeInsets.all(12),
            height: 80,
            child: Stack(
              children: [
                if (mediaItem!.artUri != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          mediaItem!.artUri.toString(),
                          fit: BoxFit.cover,
                        ),
                        BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Container(
                            color: Colors.black.withAlpha((0.4 * 255).round()),
                          ),
                        ),
                      ],
                    ),
                  ),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withAlpha((0.2 * 255).round()),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (mediaItem!.artUri != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            mediaItem!.artUri.toString(),
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          ),
                        ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              mediaItem!.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              mediaItem!.artist ?? '',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.skip_previous,
                          color: Colors.white,
                        ),
                        onPressed: isLoading ? null : onPrevious,
                      ),
                      if (isLoading)
                        const SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        StreamBuilder<PlayerState>(
                          stream: player.playerStateStream,
                          builder: (context, snapshot) {
                            final isPlaying = snapshot.data?.playing ?? false;
                            return IconButton(
                              icon: Icon(
                                isPlaying
                                    ? Icons.pause_circle_filled
                                    : Icons.play_circle_fill,
                                color: Colors.white,
                                size: 32,
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
                      IconButton(
                        icon: const Icon(Icons.skip_next, color: Colors.white),
                        onPressed: isLoading ? null : onNext,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
