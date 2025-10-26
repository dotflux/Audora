import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class PositionSlider extends StatelessWidget {
  final AudioPlayer player;
  final bool isDragging;
  final double dragValue;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeStart;
  final ValueChanged<double> onChangeEnd;
  final ValueNotifier<bool>? isLoadingNotifier;

  const PositionSlider({
    super.key,
    required this.player,
    required this.isDragging,
    required this.dragValue,
    required this.onChanged,
    required this.onChangeStart,
    required this.onChangeEnd,
    this.isLoadingNotifier,
  });

  String formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? "$hours:$minutes:$seconds" : "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    const double horizontalPadding = 20.0;

    return ValueListenableBuilder<bool>(
      valueListenable: isLoadingNotifier ?? ValueNotifier(false),
      builder: (context, isLoading, _) {
        return StreamBuilder<Duration?>(
          stream: player.durationStream,
          builder: (context, durSnapshot) {
            final duration = durSnapshot.data ?? Duration.zero;
            final maxMillis = duration.inMilliseconds > 0
                ? duration.inMilliseconds
                : 1;

            return StreamBuilder<Duration>(
              stream: player.positionStream,
              builder: (context, posSnapshot) {
                final pos = posSnapshot.data ?? Duration.zero;
                final currentMillis = isLoading
                    ? 0.0
                    : pos.inMilliseconds.toDouble();
                final value = isDragging
                    ? dragValue
                    : currentMillis.clamp(0.0, maxMillis.toDouble());

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 1,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 1,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 3,
                            ),
                            activeTrackColor: Colors.white,
                            inactiveTrackColor: Colors.white12,
                            thumbColor: Colors.white60,
                          ),
                          child: Slider(
                            value: value,
                            min: 0,
                            max: maxMillis.toDouble(),
                            onChangeStart: onChangeStart,
                            onChanged: onChanged,
                            onChangeEnd: onChangeEnd,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            formatDuration(
                              Duration(milliseconds: value.toInt()),
                            ),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            formatDuration(duration),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
