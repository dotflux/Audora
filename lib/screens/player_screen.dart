import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import '../widgets/glow_album_art.dart';
import '../widgets/position_slider.dart';
import '../widgets/playback_controls.dart';
import '../widgets/animated_equalizer.dart';
import '../widgets/track_info.dart';

class PlayerScreen extends StatefulWidget {
  final AudioPlayer player;
  final MediaItem mediaItem;
  final ValueNotifier<bool>? isLoadingNotifier;
  final ValueNotifier<MediaItem?> currentTrackNotifier;

  final VoidCallback? onNext;
  final VoidCallback? onPrevious;

  const PlayerScreen({
    super.key,
    required this.player,
    required this.mediaItem,
    this.isLoadingNotifier,
    required this.currentTrackNotifier,
    this.onNext,
    this.onPrevious,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  bool _isDragging = false;
  double _dragValue = 0.0;
  bool _isLiked = false;
  LoopMode _loopMode = LoopMode.off;

  MediaItem? media;

  @override
  void initState() {
    super.initState();
    media = widget.currentTrackNotifier.value;

    widget.currentTrackNotifier.addListener(_onTrackChanged);
    widget.isLoadingNotifier?.addListener(_onLoadingChanged);
  }

  void _onTrackChanged() {
    if (!mounted) return;
    setState(() {
      media = widget.currentTrackNotifier.value;
      _dragValue = 0.0;
      _isDragging = false;
    });
  }

  void _onLoadingChanged() {
    if (!mounted) return;
    setState(() {});
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

  @override
  void dispose() {
    widget.currentTrackNotifier.removeListener(_onTrackChanged);
    widget.isLoadingNotifier?.removeListener(_onLoadingChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (media == null) return const SizedBox.shrink();

    final bottomPadding = MediaQuery.of(context).padding.bottom > 0
        ? MediaQuery.of(context).padding.bottom
        : 8.0;

    return Stack(
      children: [
        if (media!.artUri != null) ...[
          Positioned.fill(
            child: Image.network(media!.artUri.toString(), fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
              child: Container(color: const Color.fromRGBO(0, 0, 0, 0.55)),
            ),
          ),
        ],
        Scaffold(
          backgroundColor: Colors.transparent,
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
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (media!.artUri != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: GlowingAlbumArt(
                            imageUrl: media!.artUri.toString(),
                            size: 340,
                            borderRadius: 16,
                          ),
                        ),
                      const SizedBox(height: 18),
                      TrackInfo(
                        title: media!.title,
                        artist: media!.artist ?? '',
                      ),
                      const SizedBox(height: 14),
                      PositionSlider(
                        player: widget.player,
                        isDragging: _isDragging,
                        dragValue: _dragValue,
                        onChanged: (v) => setState(() => _dragValue = v),
                        onChangeStart: (v) =>
                            setState(() => _isDragging = true),
                        onChangeEnd: (v) {
                          setState(() => _isDragging = false);
                          widget.player.seek(Duration(milliseconds: v.toInt()));
                        },
                        isLoadingNotifier: widget.isLoadingNotifier,
                      ),
                      const SizedBox(height: 24),
                      const AnimatedEqualizer(),
                      const SizedBox(height: 14),
                      PlaybackControls(
                        player: widget.player,
                        isLiked: _isLiked,
                        onLike: () => setState(() => _isLiked = !_isLiked),
                        loopMode: _loopMode,
                        cycleLoopMode: _cycleLoopMode,
                        isLoadingNotifier: widget.isLoadingNotifier,
                        onNext: widget.onNext,
                        onPrevious: widget.onPrevious,
                      ),
                      SizedBox(height: bottomPadding),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
