import 'package:flutter/material.dart';
import 'dart:io';
import '../data/downloads.dart';
import '../data/download_progress.dart';
import '../audio_manager.dart';
import '../audora_music.dart';
import 'dart:async';

class DownloadsScreen extends StatefulWidget {
  final AudioManager audioManager;

  const DownloadsScreen({super.key, required this.audioManager});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  List<DownloadedTrack> _downloads = [];
  Map<String, DownloadProgress> _progressMap = {};
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();
    _loadDownloads();
    _loadProgress();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _loadProgress();
    });
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  void _loadDownloads() {
    setState(() {
      _downloads = Downloads.getAll();
    });
  }

  void _loadProgress() {
    setState(() {
      _progressMap = DownloadProgressTracker.getAll();
    });
  }

  Future<void> _deleteDownload(DownloadedTrack track) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF181818),
        title: const Text(
          'Delete Download',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Delete "${track.title}"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await Downloads.remove(track.videoId);
      _loadDownloads();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Download deleted'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _playDownload(DownloadedTrack track) async {
    final audioFile = File(track.audioPath);
    if (!await audioFile.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Audio file not found'),
            backgroundColor: Colors.red,
          ),
        );
      }
      await Downloads.remove(track.videoId);
      _loadDownloads();
      return;
    }

    try {
      final allDownloads = Downloads.getAll();
      final downloadQueue = allDownloads.map((dt) {
        final artUri =
            dt.albumArtPath != null && File(dt.albumArtPath!).existsSync()
            ? Uri.file(dt.albumArtPath!)
            : null;
        return Track(
          videoId: dt.videoId,
          title: dt.title,
          artist: dt.artist,
          thumbnail: artUri?.toString(),
        );
      }).toList();

      final artUri =
          track.albumArtPath != null && File(track.albumArtPath!).existsSync()
          ? Uri.file(track.albumArtPath!)
          : null;

      final trackObj = Track(
        videoId: track.videoId,
        title: track.title,
        artist: track.artist,
        thumbnail: artUri?.toString(),
      );

      await widget.audioManager.playTrack(trackObj, queue: downloadQueue);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to play: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        titleSpacing: 10,
        title: Row(
          children: [
            Image.asset('assets/icon/AudoraNoText.png', width: 34, height: 34),
            const SizedBox(width: 8),
            const Text(
              'AUDORA',
              style: TextStyle(
                fontSize: 22,
                letterSpacing: 1.6,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          if (_downloads.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.white70),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: const Color(0xFF181818),
                    title: const Text(
                      'Clear All',
                      style: TextStyle(color: Colors.white),
                    ),
                    content: const Text(
                      'Delete all downloads?',
                      style: TextStyle(color: Colors.white70),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text(
                          'Clear',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await Downloads.clearAll();
                  _loadDownloads();
                }
              },
            ),
        ],
      ),
      body: Builder(
        builder: (context) {
          final inProgressDownloads = _progressMap.values
              .where(
                (progress) =>
                    progress.progress < 100 &&
                    !Downloads.isDownloaded(progress.videoId),
              )
              .toList();

          final completedDownloads = _downloads;

          final allItems = <_DownloadItem>[];

          for (final progress in inProgressDownloads) {
            allItems.add(
              _DownloadItem(
                videoId: progress.videoId,
                title: progress.title ?? 'Unknown',
                artist: progress.artist ?? 'Unknown',
                progress: progress,
                isCompleted: false,
              ),
            );
          }

          for (final track in completedDownloads) {
            final progress = _progressMap[track.videoId];
            allItems.add(
              _DownloadItem(
                videoId: track.videoId,
                title: track.title,
                artist: track.artist,
                track: track,
                progress: progress,
                isCompleted: true,
              ),
            );
          }

          if (allItems.isEmpty) {
            return const Center(
              child: Text(
                "No downloads yet.\nDownload tracks from the player screen.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 15),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: allItems.length,
            itemBuilder: (context, index) {
              final item = allItems[index];
              final track = item.track;
              final progress = item.progress;
              final isInProgress =
                  item.isCompleted == false ||
                  (progress != null && progress.progress < 100);

              File? artFile;
              bool hasArt = false;
              if (track != null && track.albumArtPath != null) {
                artFile = File(track.albumArtPath!);
                hasArt = artFile.existsSync();
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white.withOpacity(0.05),
                ),
                child: ListTile(
                  onTap: isInProgress
                      ? null
                      : track != null
                      ? () => _playDownload(track)
                      : null,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: hasArt && artFile != null
                        ? Image.file(
                            artFile,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 60,
                            height: 60,
                            color: Colors.white24,
                            child: const Icon(
                              Icons.music_note,
                              color: Colors.white54,
                              size: 30,
                            ),
                          ),
                  ),
                  title: Text(
                    item.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.artist,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      _buildDownloadStatusForItem(item),
                    ],
                  ),
                  trailing: isInProgress
                      ? null
                      : track != null
                      ? IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                          ),
                          onPressed: () => _deleteDownload(track),
                        )
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDownloadStatusForItem(_DownloadItem item) {
    final progress = item.progress;
    if (progress != null && progress.progress < 100) {
      return Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'Downloading..',
              style: TextStyle(
                color: Colors.blue.withOpacity(0.8),
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }
    if (item.isCompleted) {
      return Row(
        children: [
          const Icon(Icons.download_done, color: Colors.green, size: 14),
          const SizedBox(width: 4),
          Text(
            'Downloaded',
            style: TextStyle(
              color: Colors.green.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}

class _DownloadItem {
  final String videoId;
  final String title;
  final String artist;
  final DownloadedTrack? track;
  final DownloadProgress? progress;
  final bool isCompleted;

  _DownloadItem({
    required this.videoId,
    required this.title,
    required this.artist,
    this.track,
    this.progress,
    required this.isCompleted,
  });
}
