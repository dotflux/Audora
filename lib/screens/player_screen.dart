import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';

class PlayerScreen extends StatefulWidget {
  final AudioPlayer player;
  final MediaItem mediaItem;

  const PlayerScreen({
    super.key,
    required this.player,
    required this.mediaItem,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  bool _isDragging = false;
  double _dragValue = 0.0;
  bool _isLiked = false;
  LoopMode _loopMode = LoopMode.off;

  String formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  void _cycleLoopMode() {
    setState(() {
      if (_loopMode == LoopMode.off) {
        _loopMode = LoopMode.all;
      } else if (_loopMode == LoopMode.all) {
        _loopMode = LoopMode.one;
      } else {
        _loopMode = LoopMode.off;
      }
    });
    widget.player.setLoopMode(_loopMode);
  }

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
    final player = widget.player;
    final media = widget.mediaItem;

    const double horizontalPadding = 20.0;
    const double albumSize = 340.0;
    const double playButtonSize = 78.0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Audora',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
      ),
      body: Stack(
        children: [
          if (media.artUri != null)
            Positioned.fill(
              child: Image.network(media.artUri.toString(), fit: BoxFit.cover),
            ),
          if (media.artUri != null)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
                child: Container(color: const Color.fromRGBO(0, 0, 0, 0.55)),
              ),
            ),

          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (media.artUri != null)
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: horizontalPadding + 8,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.network(
                                media.artUri.toString(),
                                width: albumSize,
                                height: albumSize,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        const SizedBox(height: 18),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  media.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  media.artist ?? '',
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
                        ),
                        const SizedBox(height: 14),

                        StreamBuilder<Duration?>(
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
                                final currentMillis = pos.inMilliseconds
                                    .toDouble();
                                final value = _isDragging
                                    ? _dragValue
                                    : currentMillis.clamp(
                                        0.0,
                                        maxMillis.toDouble(),
                                      );

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
                                            thumbShape:
                                                const RoundSliderThumbShape(
                                                  enabledThumbRadius: 0,
                                                ),
                                            overlayShape:
                                                const RoundSliderOverlayShape(
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
                                            onChangeStart: (v) {
                                              setState(() {
                                                _isDragging = true;
                                                _dragValue = v;
                                              });
                                            },
                                            onChanged: (v) =>
                                                setState(() => _dragValue = v),
                                            onChangeEnd: (v) {
                                              setState(
                                                () => _isDragging = false,
                                              );
                                              player.seek(
                                                Duration(
                                                  milliseconds: v.toInt(),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            formatDuration(
                                              Duration(
                                                milliseconds: value.toInt(),
                                              ),
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
                        ),

                        const SizedBox(height: 24),

                        const _AnimatedEqualizer(),

                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: 10.0,
                  ),
                  child: StreamBuilder<PlayerState>(
                    stream: player.playerStateStream,
                    builder: (context, snapshot) {
                      final isPlaying = snapshot.data?.playing ?? false;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _fancyButton(
                            _isLiked ? Icons.favorite : Icons.favorite_border,
                            size: 22,
                            active: _isLiked,
                            onPressed: () =>
                                setState(() => _isLiked = !_isLiked),
                          ),
                          _fancyButton(
                            Icons.skip_previous,
                            size: 28,
                            onPressed: () async =>
                                await player.seekToPrevious(),
                          ),
                          Container(
                            width: playButtonSize + 18,
                            height: playButtonSize + 18,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color.fromRGBO(
                                    43,
                                    108,
                                    255,
                                    0.22,
                                  ),
                                  blurRadius: 20,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: IconButton(
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
                            onPressed: () async => await player.seekToNext(),
                          ),
                          _fancyButton(
                            _loopMode == LoopMode.one
                                ? Icons.repeat_one
                                : Icons.repeat,
                            size: 22,
                            active: _loopMode != LoopMode.off,
                            onPressed: _cycleLoopMode,
                          ),
                        ],
                      );
                    },
                  ),
                ),
                SizedBox(
                  height: MediaQuery.of(context).padding.bottom > 0
                      ? MediaQuery.of(context).padding.bottom
                      : 8,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedEqualizer extends StatefulWidget {
  const _AnimatedEqualizer();

  @override
  State<_AnimatedEqualizer> createState() => _AnimatedEqualizerState();
}

class _AnimatedEqualizerState extends State<_AnimatedEqualizer> {
  late Timer _timer;
  final List<double> _heights = List.generate(20, (_) => 10);
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      setState(() {
        for (int i = 0; i < _heights.length; i++) {
          _heights[i] = 5 + _random.nextDouble() * 30;
        }
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_heights.length, (i) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 4,
            height: _heights[i],
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.6),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }
}
