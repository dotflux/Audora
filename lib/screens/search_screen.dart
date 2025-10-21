import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../audora_music.dart';
import '../widgets/mini_player.dart';
import 'package:audio_service/audio_service.dart';
import 'dart:convert';
import 'dart:io';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final AudoraClient _client = AudoraClient();
  late final AudoraPlayer _player;
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<Track> _tracks = [];
  bool _isLoading = false;
  MediaItem? _currentTrack;
  Map<String, dynamic>? _currentTrackMap;

  @override
  void initState() {
    super.initState();
    _player = AudoraPlayer(_client);
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _tracks = [];
    });

    try {
      final visitorData = await _client.getVisitorData();
      final results = await AudoraSearch(
        _client,
      ).search(query, visitorData: visitorData);

      setState(() {
        _tracks = results;
        _isLoading = false;
      });
    } catch (e, stack) {
      setState(() => _isLoading = false);
      print('[ERROR] Search failed: $e');
      print(stack);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Search failed: $e')));
    }
  }

  Future<void> _playTrack(Track track) async {
    try {
      final audioData = await _player.getAudioFromServer(track.videoId);

      if (audioData == null || audioData['url'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to fetch audio from server')),
        );
        return;
      }

      final safeUrl = audioData['url'] as String;

      print('Audio URL from Node server: $safeUrl');

      _currentTrackMap = {
        'id': track.videoId,
        'title': track.title,
        'artist': track.artist,
        'url': safeUrl,
        'thumbnail': track.thumbnail,
      };

      await _audioPlayer.setAudioSource(
        AudioSource.uri(
          Uri.parse(safeUrl),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:88.0) Gecko/20100101 Firefox/88.0',
            'Referer': safeUrl,
            'Accept': '*/*',
          },
        ),
      );

      await _audioPlayer.play();

      setState(() {
        _currentTrack = MediaItem(
          id: _currentTrackMap!['id'],
          album: "YouTube Music",
          title: _currentTrackMap!['title'],
          artist: _currentTrackMap!['artist'],
          artUri: _currentTrackMap!['thumbnail'] != null
              ? Uri.parse(_currentTrackMap!['thumbnail'])
              : null,
        );
      });

      print('[OK] Playing ${_currentTrackMap!['title']} ✅');
    } catch (e, st) {
      print('[ERROR] Playback failed: $e');
      print('[STACK] $st');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error playing track: $e')));
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Search Tracks",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: "Search songs...",
                          hintStyle: TextStyle(color: Colors.white70),
                          border: OutlineInputBorder(),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                        onSubmitted: _search,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.search, color: Colors.white),
                      onPressed: () => _search(_searchController.text.trim()),
                    ),
                  ],
                ),
              ),
              if (_isLoading) const LinearProgressIndicator(),
              Expanded(
                child: _tracks.isEmpty && !_isLoading
                    ? const Center(
                        child: Text(
                          "No results",
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _tracks.length,
                        itemBuilder: (context, index) {
                          final track = _tracks[index];
                          return ListTile(
                            leading: track.thumbnail != null
                                ? Image.network(
                                    track.thumbnail!,
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                  )
                                : const Icon(
                                    Icons.music_note,
                                    size: 50,
                                    color: Colors.white,
                                  ),
                            title: Text(
                              track.title,
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              track.artist,
                              style: const TextStyle(color: Colors.white70),
                            ),
                            onTap: () => _playTrack(track),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 70),
            ],
          ),
          if (_currentTrack != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: MiniPlayer(
                player: _audioPlayer,
                mediaItem: _currentTrack!,
              ),
            ),
        ],
      ),
    );
  }
}
