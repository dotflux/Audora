import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class PlaybackControls extends StatelessWidget {
  final AudioPlayer player;
  final bool hasBestPart;
  final VoidCallback onGoToBestPart;
  final LoopMode loopMode;
  final VoidCallback cycleLoopMode;
  final ValueNotifier<bool>? isLoadingNotifier;

  final VoidCallback? onNext;
  final VoidCallback? onPrevious;

  const PlaybackControls({
    super.key,
    required this.player,
    required this.hasBestPart,
    required this.onGoToBestPart,
    required this.loopMode,
    required this.cycleLoopMode,
    this.isLoadingNotifier,
    this.onNext,
    this.onPrevious,
  });

  Widget _fancyButton(
    IconData icon, {
    VoidCallback? onPressed,
    double size = 28,
    bool active = false,
  }) {
    final bg = active
        ? BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xff2b6cff), Color(0xff4aa3ff)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Color.fromRGBO(43, 108, 255, 0.25),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
            shape: BoxShape.circle,
          )
        : BoxDecoration(
            color: const Color.fromRGBO(255, 255, 255, 0.03),
            borderRadius: BorderRadius.circular(40),
          );

    return Container(
      width: size + 28,
      height: size + 28,
      decoration: bg,
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(
          icon,
          color: active ? Colors.white : Colors.white70,
          size: size,
        ),
        onPressed: onPressed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const double playButtonSize = 78.0;

    return ValueListenableBuilder<bool>(
      valueListenable: isLoadingNotifier ?? ValueNotifier(false),
      builder: (context, isLoading, _) {
        return StreamBuilder<PlayerState>(
          stream: player.playerStateStream,
          builder: (context, snapshot) {
            final isPlaying = snapshot.data?.playing ?? false;

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _fancyButton(
                  Icons.replay,
                  size: 22,
                  onPressed: hasBestPart ? onGoToBestPart : null,
                ),
                _fancyButton(
                  Icons.skip_previous,
                  size: 28,
                  onPressed: isLoadingNotifier?.value ?? false
                      ? null
                      : onPrevious,
                ),
                Container(
                  width: playButtonSize + 18,
                  height: playButtonSize + 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color.fromRGBO(43, 108, 255, 0.22),
                        blurRadius: 20,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: isLoading
                        ? const Center(
                            child: SizedBox(
                              width: 40,
                              height: 40,
                              child: CircularProgressIndicator(strokeWidth: 3),
                            ),
                          )
                        : IconButton(
                            iconSize: playButtonSize,
                            icon: Icon(
                              isPlaying
                                  ? Icons.pause_circle_filled
                                  : Icons.play_circle_fill,
                              color: Colors.white,
                            ),
                            onPressed: () =>
                                isPlaying ? player.pause() : player.play(),
                          ),
                  ),
                ),
                _fancyButton(
                  Icons.skip_next,
                  size: 28,
                  onPressed: isLoadingNotifier?.value ?? false ? null : onNext,
                ),
                _fancyButton(
                  loopMode == LoopMode.one ? Icons.repeat_one : Icons.repeat,
                  size: 22,
                  active: loopMode != LoopMode.off,
                  onPressed: isLoading ? null : cycleLoopMode,
                ),
              ],
            );
          },
        );
      },
    );
  }
}
