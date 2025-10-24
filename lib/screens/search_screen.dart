import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../audora_music.dart';
import '../widgets/mini_player.dart';
import 'package:audio_service/audio_service.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

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
  bool _isFetching = false;
  MediaItem? _currentTrack;
  Map<String, dynamic>? _currentTrackMap;
  String? _currentPlayingVideoId;

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

  Future<File?> _getCachedAudio(String videoId) async {
    final tempDir = await getTemporaryDirectory();
    final extensions = ['m4a', 'mp3', 'mp4'];
    for (var ext in extensions) {
      final file = File('${tempDir.path}/$videoId.$ext');
      if (file.existsSync()) return file;
    }
    return null;
  }

  Future<void> _playTrack(Track track) async {
    await _audioPlayer.stop();
    setState(() => _isFetching = false);

    _currentPlayingVideoId = track.videoId;

    setState(() {
      _currentTrack = MediaItem(
        id: track.videoId,
        album: "YouTube Music",
        title: track.title,
        artist: track.artist,
        artUri: track.thumbnail != null ? Uri.parse(track.thumbnail!) : null,
      );
    });

    File? file = await _getCachedAudio(track.videoId);

    if (file == null) {
      setState(() => _isFetching = true);

      try {
        final audioData = await _player.getAudioFromServer(track.videoId);
        if (audioData == null || audioData['url'] == null) return;

        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/${track.videoId}.m4a';
        file = File(filePath);

        if (file.existsSync()) await file.delete();

        final request = await HttpClient().getUrl(Uri.parse(audioData['url']));
        final response = await request.close();
        final bytes = await consolidateHttpClientResponseBytes(response);
        await file.writeAsBytes(bytes);

        if (_currentPlayingVideoId != track.videoId) {
          print('[INFO] Track changed during fetch, ignoring ${track.title}');
          return;
        }
      } catch (e, st) {
        print('[ERROR] Playback failed: $e');
        print(st);
        return;
      } finally {
        setState(() => _isFetching = false);
      }
    }

    if (_currentPlayingVideoId != track.videoId) return;

    await _audioPlayer.setAudioSource(AudioSource.file(file.path));
    await _audioPlayer.play();

    _currentTrackMap = {
      'id': track.videoId,
      'title': track.title,
      'artist': track.artist,
      'url': file.path,
      'thumbnail': track.thumbnail,
    };

    print('[OK] Playing ${track.title} ✅');
  }

  @override
  void dispose() {
    _searchController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 10),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Search songs, artists...",
                      hintStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Color(0xFF121212),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.white70,
                      ),
                    ),
                    onSubmitted: _search,
                  ),
                ),
              ),

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: LinearProgressIndicator(
                    color: Color(0xFF0A84FF),
                    backgroundColor: Colors.transparent,
                    minHeight: 2,
                  ),
                ),
              const SizedBox(height: 10),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _tracks.isEmpty && !_isLoading
                      ? const Center(
                          child: Text(
                            "No results yet. Try searching something.",
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 16,
                            ),
                          ),
                        )
                      : ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          itemCount: _tracks.length,
                          itemBuilder: (context, index) {
                            final track = _tracks[index];
                            return GestureDetector(
                              onTap: () => _playTrack(track),
                              child: AnimatedScale(
                                duration: const Duration(milliseconds: 120),
                                scale: 1.0,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  child: Row(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(4.0),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: track.thumbnail != null
                                              ? Image.network(
                                                  track.thumbnail!,
                                                  width: 55,
                                                  height: 55,
                                                  fit: BoxFit.cover,
                                                )
                                              : Container(
                                                  width: 55,
                                                  height: 55,
                                                  color: Colors.white
                                                      .withValues(alpha: 0.05),
                                                  child: const Icon(
                                                    Icons.music_note,
                                                    color: Colors.white54,
                                                    size: 30,
                                                  ),
                                                ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              track.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              track.artist,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white54,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
          if (_currentTrack != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.92),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: MiniPlayer(
                  player: _audioPlayer,
                  mediaItem: _currentTrack!,
                  isLoading: _isFetching,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
