import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import '../audora_music.dart';

const String lrcBase = 'https://lrclib.net';

Future<Map<String, dynamic>?> getLRCByQuery({
  required String trackName,
  required String artistName,
  String? albumName,
  int? duration,
}) async {
  final params = <String, String>{
    'track_name': trackName,
    'artist_name': artistName,
  };
  if (albumName != null) params['album_name'] = albumName;
  if (duration != null) params['duration'] = duration.toString();
  final uri = Uri.parse('$lrcBase/api/get').replace(queryParameters: params);
  final res = await http.get(uri);
  if (res.statusCode != 200) return null;
  return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
}

class LyricsWidget extends StatefulWidget {
  final Track track;
  final AudioPlayer? player;
  final MediaItem? mediaItem;
  final ScrollController? scrollController;

  const LyricsWidget({
    super.key,
    required this.track,
    this.player,
    this.mediaItem,
    this.scrollController,
  });

  @override
  State<LyricsWidget> createState() => _LyricsWidgetState();
}

class _LyricsWidgetState extends State<LyricsWidget> {
  bool _isLoading = true;
  String _error = '';
  List<_LyricLine> _lines = [];
  Duration? _currentPosition;

  @override
  void initState() {
    super.initState();
    _fetchLyrics();
    if (widget.player != null) {
      widget.player!.positionStream.listen((pos) {
        if (mounted) {
          setState(() {
            _currentPosition = pos;
          });
        }
      });
    }
  }

  Future<void> _fetchLyrics() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final lyrics = await getLRCByQuery(
        trackName: widget.track.title,
        artistName: widget.track.artist,
        duration: widget.track.durationSec,
      );

      if (lyrics == null || lyrics['syncedLyrics'] == null) {
        setState(() {
          _error = 'No lyrics found';
          _isLoading = false;
        });
        return;
      }

      final syncedLyrics = lyrics['syncedLyrics'] as String;
      _lines = _parseLRC(syncedLyrics);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load lyrics';
        _isLoading = false;
      });
    }
  }

  List<_LyricLine> _parseLRC(String lrc) {
    final lines = <_LyricLine>[];
    final linePattern = RegExp(r'\[(\d+):(\d+).(\d+)\](.*)');

    for (final line in lrc.split('\n')) {
      final match = linePattern.firstMatch(line);
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final milliseconds = int.parse(match.group(3)!);
        final text = match.group(4)!.trim();

        if (text.isNotEmpty) {
          final time = Duration(
            minutes: minutes,
            seconds: seconds,
            milliseconds: milliseconds * 10,
          );
          lines.add(_LyricLine(time: time, text: text));
        }
      }
    }

    lines.sort((a, b) => a.time.compareTo(b.time));
    return lines;
  }

  void _seekToLine(_LyricLine line) {
    if (widget.player != null) {
      widget.player!.seek(line.time);
    }
  }

  int _getCurrentLineIndex() {
    if (_currentPosition == null || _lines.isEmpty) return -1;
    for (int i = _lines.length - 1; i >= 0; i--) {
      if (_lines[i].time <= _currentPosition!) {
        return i;
      }
    }
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_error.isNotEmpty) {
      return Center(
        child: Text(_error, style: const TextStyle(color: Colors.white70)),
      );
    }

    if (_lines.isEmpty) {
      return Center(
        child: Text(
          'No synced lyrics available',
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }

    final currentIndex = _getCurrentLineIndex();

    return ListView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _lines.length,
      itemBuilder: (context, index) {
        final line = _lines[index];
        final isActive = index == currentIndex;
        final isNearActive = (index - currentIndex).abs() <= 2;

        return GestureDetector(
          onTap: () => _seekToLine(line),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Text(
              line.text,
              style: TextStyle(
                color: isActive
                    ? Colors.white
                    : isNearActive
                    ? Colors.white70
                    : Colors.white38,
                fontSize: isActive ? 18 : 16,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );
  }
}

class _LyricLine {
  final Duration time;
  final String text;

  _LyricLine({required this.time, required this.text});
}
