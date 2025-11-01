import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import '../widgets/glow_album_art.dart';
import '../widgets/position_slider.dart';
import '../widgets/playback_controls.dart';
import '../widgets/animated_equalizer.dart';
import '../widgets/track_info.dart';
import '../audio_manager.dart';
import '../data/track_best_parts.dart';
import '../audora_music.dart';

class PlayerScreen extends StatefulWidget {
  final AudioPlayer player;
  final MediaItem mediaItem;
  final ValueNotifier<bool>? isLoadingNotifier;
  final ValueNotifier<MediaItem?> currentTrackNotifier;
  final AudioManager audioManager;

  final VoidCallback? onNext;
  final VoidCallback? onPrevious;

  const PlayerScreen({
    super.key,
    required this.player,
    required this.mediaItem,
    this.isLoadingNotifier,
    required this.currentTrackNotifier,
    required this.audioManager,
    this.onNext,
    this.onPrevious,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  bool _isDragging = false;
  double _dragValue = 0.0;
  final DraggableScrollableController _queueController =
      DraggableScrollableController();

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
    final current = widget.audioManager.getLoopMode();
    final next = current == LoopMode.off
        ? LoopMode.all
        : current == LoopMode.all
        ? LoopMode.one
        : LoopMode.off;
    widget.audioManager.setLoopMode(next);
  }

  void _showOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF181818),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.loop, color: Colors.white70),
                title: const Text(
                  'Set Best Part',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showSetBestPart();
                },
              ),
              if (media != null && TrackBestParts.hasBestPart(media!.id))
                ListTile(
                  leading: const Icon(Icons.refresh, color: Colors.white70),
                  title: const Text(
                    'Reset Best Part',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await TrackBestParts.resetBestPart(media!.id);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Best part reset!'),
                          duration: Duration(seconds: 2),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  },
                ),
              ListTile(
                leading: const Icon(Icons.queue_music, color: Colors.white70),
                title: const Text(
                  'Queue',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _queueController.animateTo(
                    0.5,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSetBestPart() {
    final videoId = media?.id;
    if (videoId == null) return;

    final currentPos = widget.player.position.inMilliseconds;
    final duration = widget.player.duration?.inMilliseconds ?? 0;
    int selectedMs = currentPos;

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            children: [
              if (media?.artUri != null)
                Positioned.fill(
                  child: Image.network(
                    media!.artUri.toString(),
                    fit: BoxFit.cover,
                  ),
                ),
              if (media?.artUri != null)
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
                    child: Container(color: const Color.fromRGBO(0, 0, 0, 0.7)),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Set Best Part',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      _formatDuration(Duration(milliseconds: selectedMs)),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 32),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 10,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 20,
                        ),
                        activeTrackColor: Colors.blue,
                        inactiveTrackColor: Colors.white24,
                        thumbColor: Colors.blue,
                      ),
                      child: Slider(
                        value: selectedMs.toDouble(),
                        min: 0,
                        max: duration > 0 ? duration.toDouble() : 1.0,
                        onChanged: (v) {
                          setDialogState(() {
                            selectedMs = v.toInt();
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(Duration(milliseconds: 0)),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          _formatDuration(Duration(milliseconds: duration)),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              await TrackBestParts.setBestPart(
                                videoId,
                                selectedMs,
                              );
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Best part set!'),
                                  duration: Duration(seconds: 2),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text(
                              'Set',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = d.inHours;
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
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
            actions: [
              IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onPressed: _showOptions,
              ),
            ],
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
                      ValueListenableBuilder<LoopMode>(
                        valueListenable: widget.audioManager.loopModeNotifier,
                        builder: (context, loopMode, _) {
                          return PlaybackControls(
                            player: widget.player,
                            hasBestPart: widget.audioManager.hasBestPart(),
                            onGoToBestPart: widget.audioManager.seekToBestPart,
                            loopMode: loopMode,
                            cycleLoopMode: _cycleLoopMode,
                            isLoadingNotifier: widget.isLoadingNotifier,
                            onNext: widget.onNext,
                            onPrevious: widget.onPrevious,
                          );
                        },
                      ),
                      SizedBox(height: bottomPadding),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildQueueSheet(),
      ],
    );
  }

  Widget _buildQueueSheet() {
    return ValueListenableBuilder<List<Track>>(
      valueListenable: widget.audioManager.queueNotifier,
      builder: (context, queue, _) {
        final currentIndex = widget.audioManager.currentIndex;

        return DraggableScrollableSheet(
          controller: _queueController,
          initialChildSize: 0.0,
          minChildSize: 0.0,
          maxChildSize: 0.85,
          builder: (context, scrollController) {
            return Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Stack(
                  children: [
                    if (media?.artUri != null)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Image.network(
                                media!.artUri.toString(),
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned.fill(
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 32,
                                  sigmaY: 32,
                                ),
                                child: Container(
                                  color: const Color.fromRGBO(0, 0, 0, 0.85),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Column(
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
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Queue',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white70,
                                ),
                                onPressed: () => _queueController.animateTo(
                                  0.0,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeIn,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            controller: scrollController,
                            itemCount: queue.length,
                            itemBuilder: (context, index) {
                              final track = queue[index];
                              final isCurrent = index == currentIndex;
                              return Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isCurrent
                                      ? Colors.blue.withOpacity(0.2)
                                      : Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: isCurrent
                                      ? Border.all(
                                          color: Colors.blue.withOpacity(0.5),
                                          width: 1,
                                        )
                                      : null,
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: track.thumbnail != null
                                        ? Image.network(
                                            track.thumbnail!,
                                            width: 56,
                                            height: 56,
                                            fit: BoxFit.cover,
                                          )
                                        : Container(
                                            width: 56,
                                            height: 56,
                                            color: Colors.white24,
                                            child: const Icon(
                                              Icons.music_note,
                                              color: Colors.white54,
                                              size: 28,
                                            ),
                                          ),
                                  ),
                                  title: Text(
                                    track.title,
                                    style: TextStyle(
                                      color: isCurrent
                                          ? Colors.blue
                                          : Colors.white,
                                      fontWeight: isCurrent
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      fontSize: 16,
                                    ),
                                  ),
                                  subtitle: Text(
                                    track.artist,
                                    style: TextStyle(
                                      color: isCurrent
                                          ? Colors.blue.withOpacity(0.8)
                                          : Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                  trailing: isCurrent
                                      ? const Icon(
                                          Icons.play_arrow,
                                          color: Colors.blue,
                                          size: 28,
                                        )
                                      : null,
                                  onTap: () {
                                    widget.audioManager.setCurrentIndex(index);
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
