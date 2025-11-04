import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../widgets/glow_album_art.dart';
import '../widgets/position_slider.dart';
import '../widgets/playback_controls.dart';
import '../widgets/animated_equalizer.dart';
import '../widgets/track_info.dart';
import '../widgets/lyrics.dart';
import '../widgets/track_image.dart';
import '../audio_manager.dart';
import '../data/track_best_parts.dart';
import '../data/track_loop_after.dart';
import '../data/downloads.dart';
import '../data/download_progress.dart';
import '../audora_music.dart';
import '../widgets/add_to_playlist.dart';

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
  final DraggableScrollableController _lyricsController =
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
      builder: (context) => Stack(
        fit: StackFit.expand,
        children: [
          if (media?.artUri != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: media!.artUri!.scheme == 'file'
                        ? Image.file(
                            File(media!.artUri!.path),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Container(color: Colors.black),
                          )
                        : Image.network(
                            media!.artUri.toString(),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Container(color: Colors.black),
                          ),
                  ),
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
                      child: Container(
                        color: const Color.fromRGBO(0, 0, 0, 0.85),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          SafeArea(
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: SingleChildScrollView(
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
                        leading: const Icon(
                          Icons.refresh,
                          color: Colors.white70,
                        ),
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
                      leading: const Icon(
                        Icons.repeat_one,
                        color: Colors.white70,
                      ),
                      title: const Text(
                        'Set Loop After',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _showSetLoopAfter();
                      },
                    ),
                    if (media != null && TrackLoopAfter.hasLoopAfter(media!.id))
                      ListTile(
                        leading: const Icon(
                          Icons.refresh,
                          color: Colors.white70,
                        ),
                        title: const Text(
                          'Reset Loop After',
                          style: TextStyle(color: Colors.white),
                        ),
                        onTap: () async {
                          Navigator.pop(context);
                          await TrackLoopAfter.resetLoopAfter(media!.id);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Loop after reset!'),
                                duration: Duration(seconds: 2),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        },
                      ),
                    ListTile(
                      leading: const Icon(
                        Icons.download,
                        color: Colors.white70,
                      ),
                      title: const Text(
                        'Download',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _downloadTrack();
                      },
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.playlist_add,
                        color: Colors.white70,
                      ),
                      title: const Text(
                        'Add to Playlist',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        if (media != null) {
                          final track = Track(
                            videoId: media!.id,
                            title: media!.title,
                            artist: media!.artist ?? '',
                            thumbnail: media!.artUri?.toString(),
                          );
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => AddToPlaylistDialog(track: track),
                          );
                        }
                      },
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.queue_music,
                        color: Colors.white70,
                      ),
                      title: const Text(
                        'Queue',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          try {
                            _queueController.animateTo(
                              0.5,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                            );
                          } catch (_) {}
                        });
                      },
                    ),
                    if (media != null)
                      ListTile(
                        leading: const Icon(
                          Icons.lyrics,
                          color: Colors.white70,
                        ),
                        title: const Text(
                          'Lyrics',
                          style: TextStyle(color: Colors.white),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            try {
                              _lyricsController.animateTo(
                                0.5,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                              );
                            } catch (_) {}
                          });
                        },
                      ),
                    ListTile(
                      leading: const Icon(Icons.bedtime, color: Colors.white70),
                      title: const Text(
                        'Sleep Timer',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _showSleepTimer();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSleepTimer() {
    int hours = 0;
    int minutes = 0;
    int seconds = 0;

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
                  child: media!.artUri!.scheme == 'file'
                      ? Image.file(
                          File(media!.artUri!.path),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Container(color: Colors.black),
                        )
                      : Image.network(
                          media!.artUri.toString(),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Container(color: Colors.black),
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
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Sleep Timer',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _buildCompactTimeInput('H', hours, 0, 23, (v) {
                            setDialogState(() => hours = v);
                          }),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: _buildCompactTimeInput('M', minutes, 0, 59, (
                            v,
                          ) {
                            setDialogState(() => minutes = v);
                          }),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: _buildCompactTimeInput('S', seconds, 0, 59, (
                            v,
                          ) {
                            setDialogState(() => seconds = v);
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    ValueListenableBuilder<Duration?>(
                      valueListenable: widget.audioManager.sleepTimerNotifier,
                      builder: (context, remaining, _) {
                        if (remaining != null) {
                          return Column(
                            children: [
                              Text(
                                'Active: ${_formatSleepTimer(remaining)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: TextButton(
                                  onPressed: () {
                                    widget.audioManager.cancelSleepTimer();
                                    setDialogState(() {});
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Sleep timer cancelled'),
                                        duration: Duration(seconds: 2),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                  child: const Text(
                                    'Cancel Timer',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.pop(context),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  final duration = Duration(
                                    hours: hours,
                                    minutes: minutes,
                                    seconds: seconds,
                                  );
                                  if (duration.inSeconds > 0) {
                                    widget.audioManager.setSleepTimer(duration);
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Sleep timer set for ${_formatSleepTimer(duration)}',
                                        ),
                                        duration: const Duration(seconds: 2),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                child: const Text(
                                  'Set',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
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

  Widget _buildCompactTimeInput(
    String label,
    int value,
    int min,
    int max,
    Function(int) onChanged,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: value > min ? () => onChanged(value - 1) : null,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(value > min ? 0.15 : 0.05),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.remove, color: Colors.white, size: 16),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                value.toString().padLeft(2, '0'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            GestureDetector(
              onTap: value < max ? () => onChanged(value + 1) : null,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(value < max ? 0.15 : 0.05),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 16),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatSleepTimer(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final secs = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m ${secs}s';
    } else if (minutes > 0) {
      return '${minutes}m ${secs}s';
    }
    return '${secs}s';
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

  void _showSetLoopAfter() {
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
                      'Set Loop After',
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
                              await TrackLoopAfter.setLoopAfter(
                                videoId,
                                selectedMs,
                              );
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Loop after set!'),
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

  Future<void> _downloadTrack() async {
    if (media == null) return;
    if (Downloads.isDownloaded(media!.id)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Track already downloaded'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${appDir.path}/downloads');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      DownloadProgressTracker.update(
        media!.id,
        0,
        'Fetching audio URL...',
        title: media!.title,
        artist: media!.artist ?? '',
      );
      final audioUrl = await widget.audioManager.player.getAudioUrlExplode(
        media!.id,
      );
      if (audioUrl == null) throw Exception('Failed to get audio URL');

      DownloadProgressTracker.update(
        media!.id,
        10,
        'Downloading audio...',
        title: media!.title,
        artist: media!.artist ?? '',
      );
      final audioResponse = await http.get(Uri.parse(audioUrl));
      if (audioResponse.statusCode != 200)
        throw Exception('Failed to download audio');

      final audioPath = '${downloadsDir.path}/${media!.id}.m4a';
      final audioFile = File(audioPath);
      await audioFile.writeAsBytes(audioResponse.bodyBytes);

      String? albumArtPath;
      if (media!.artUri != null) {
        DownloadProgressTracker.update(
          media!.id,
          90,
          'Downloading album art...',
          title: media!.title,
          artist: media!.artist ?? '',
        );
        try {
          final artResponse = await http.get(media!.artUri!);
          if (artResponse.statusCode == 200) {
            albumArtPath = '${downloadsDir.path}/${media!.id}_art.jpg';
            final artFile = File(albumArtPath);
            await artFile.writeAsBytes(artResponse.bodyBytes);
          }
        } catch (_) {}
      }

      DownloadProgressTracker.update(
        media!.id,
        100,
        'Saving...',
        title: media!.title,
        artist: media!.artist ?? '',
      );
      final downloadedTrack = DownloadedTrack(
        videoId: media!.id,
        title: media!.title,
        artist: media!.artist ?? '',
        albumArtPath: albumArtPath,
        audioPath: audioPath,
        downloadedAt: DateTime.now(),
      );

      await Downloads.add(downloadedTrack);
      DownloadProgressTracker.remove(media!.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Download completed!'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      DownloadProgressTracker.remove(media!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
  Widget build(BuildContext context) {
    if (media == null) return const SizedBox.shrink();

    final bottomPadding = MediaQuery.of(context).padding.bottom > 0
        ? MediaQuery.of(context).padding.bottom
        : 8.0;

    return Stack(
      children: [
        if (media!.artUri != null) ...[
          Positioned.fill(
            child: media!.artUri!.scheme == 'file'
                ? Image.file(
                    File(media!.artUri!.path),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Container(color: Colors.black),
                  )
                : Image.network(
                    media!.artUri.toString(),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Container(color: Colors.black),
                  ),
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
              style: TextStyle(color: Colors.white, fontSize: 16),
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
                      AnimatedEqualizer(player: widget.player),
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
        _buildLyricsSheet(),
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
          snap: true,
          snapSizes: const [0.0, 0.5, 0.85],
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
                  fit: StackFit.expand,
                  children: [
                    if (media?.artUri != null)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: media!.artUri!.scheme == 'file'
                                  ? Image.file(
                                      File(media!.artUri!.path),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          Container(color: Colors.black),
                                    )
                                  : Image.network(
                                      media!.artUri.toString(),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          Container(color: Colors.black),
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
                    Positioned.fill(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onVerticalDragUpdate: (details) {
                              final delta =
                                  -details.primaryDelta! /
                                  MediaQuery.of(context).size.height;
                              final currentSize = _queueController.size;
                              final newSize = (currentSize + delta).clamp(
                                0.0,
                                0.85,
                              );
                              _queueController.jumpTo(newSize);
                            },
                            onVerticalDragEnd: (details) {
                              final size = _queueController.size;
                              if (size < 0.25) {
                                _queueController.animateTo(
                                  0.0,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeIn,
                                );
                              } else if (size < 0.675) {
                                _queueController.animateTo(
                                  0.5,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOut,
                                );
                              } else {
                                _queueController.animateTo(
                                  0.85,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOut,
                                );
                              }
                            },
                            child: Container(
                              margin: const EdgeInsets.only(top: 12, bottom: 8),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
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
                                      child: TrackImage(
                                        thumbnail: track.thumbnail,
                                        width: 56,
                                        height: 56,
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
                                      widget.audioManager.setCurrentIndex(
                                        index,
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
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
      },
    );
  }

  Widget _buildLyricsSheet() {
    if (media == null) return const SizedBox.shrink();

    final track = Track(
      videoId: media!.id,
      title: media!.title,
      artist: media!.artist ?? '',
      thumbnail: media!.artUri?.toString(),
    );

    return DraggableScrollableSheet(
      controller: _lyricsController,
      initialChildSize: 0.0,
      minChildSize: 0.0,
      maxChildSize: 0.85,
      snap: true,
      snapSizes: const [0.0, 0.5, 0.85],
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
              fit: StackFit.expand,
              children: [
                if (media?.artUri != null)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: media!.artUri!.scheme == 'file'
                              ? Image.file(
                                  File(media!.artUri!.path),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      Container(color: Colors.black),
                                )
                              : Image.network(
                                  media!.artUri.toString(),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      Container(color: Colors.black),
                                ),
                        ),
                        Positioned.fill(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
                            child: Container(
                              color: const Color.fromRGBO(0, 0, 0, 0.85),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Positioned.fill(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onVerticalDragUpdate: (details) {
                          final delta =
                              -details.primaryDelta! /
                              MediaQuery.of(context).size.height;
                          final currentSize = _lyricsController.size;
                          final newSize = (currentSize + delta).clamp(
                            0.0,
                            0.85,
                          );
                          _lyricsController.jumpTo(newSize);
                        },
                        onVerticalDragEnd: (details) {
                          final size = _lyricsController.size;
                          if (size < 0.25) {
                            _lyricsController.animateTo(
                              0.0,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeIn,
                            );
                          } else if (size < 0.675) {
                            _lyricsController.animateTo(
                              0.5,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                            );
                          } else {
                            _lyricsController.animateTo(
                              0.85,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                            );
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.only(top: 12, bottom: 8),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
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
                              'Lyrics',
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
                              onPressed: () => _lyricsController.animateTo(
                                0.0,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeIn,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: LyricsWidget(
                          track: track,
                          player: widget.player,
                          mediaItem: media,
                          scrollController: scrollController,
                        ),
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
