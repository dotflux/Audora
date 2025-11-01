import 'package:flutter/material.dart';
import 'search_screen.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import '../audio_manager.dart';
import '../audora_music.dart';
import '../widgets/mini_player.dart';
import 'playlist_screen.dart';
import 'package:audio_service/audio_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  bool _showPlaylist = false;
  String? _playlistId;
  String? _playlistTitle;
  bool _isCustomPlaylist = false;

  late final AudoraClient _client;
  late final AudoraSearch _search;
  late final AudoraPlayer _player;
  late final AudioManager _audioManager;

  @override
  void initState() {
    super.initState();
    _client = AudoraClient();
    _player = AudoraPlayer(_client);
    _search = AudoraSearch(_client);
    _audioManager = AudioManager(_player);
  }

  Future<void> openPlaylist({
    required String id,
    required String title,
    required bool isCustom,
  }) async {
    setState(() {
      _playlistId = id;
      _playlistTitle = title;
      _isCustomPlaylist = isCustom;
      _showPlaylist = true;
    });
  }

  void closePlaylist() => setState(() => _showPlaylist = false);

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        search: _search,
        audioManager: _audioManager,
        openPlaylist: openPlaylist,
      ),
      SearchScreen(audioManager: _audioManager, openPlaylist: openPlaylist),
      LibraryScreen(
        playTrack: _audioManager.playTrack,
        openPlaylist: openPlaylist,
      ),
      const Center(
        child: Text("Settings", style: TextStyle(color: Colors.white)),
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          screens[_currentIndex],

          if (_showPlaylist)
            Positioned.fill(
              child: PlaylistScreen(
                id: _playlistId!,
                title: _playlistTitle!,
                isCustom: _isCustomPlaylist,
                audioManager: _audioManager,
                search: _search,
                onBack: () {
                  closePlaylist();
                  if (_currentIndex == 2) {
                    setState(() {
                      _currentIndex = 2;
                    });
                  }
                },
              ),
            ),

          ValueListenableBuilder<MediaItem?>(
            valueListenable: _audioManager.currentTrackNotifier,
            builder: (context, currentTrack, _) {
              if (currentTrack == null) return const SizedBox.shrink();
              return Align(
                alignment: Alignment.bottomCenter,
                child: MiniPlayer(
                  key: ValueKey(currentTrack.id),
                  player: _audioManager.audioPlayer,
                  mediaItem: currentTrack,
                  isLoadingNotifier: _audioManager.isFetchingNotifier,
                  currentTrackNotifier: _audioManager.currentTrackNotifier,
                  audioManager: _audioManager,
                  onNext: _audioManager.skipToNext,
                  onPrevious: _audioManager.skipToPrevious,
                ),
              );
            },
          ),
        ],
      ),

      bottomNavigationBar: Container(
        color: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(4, (index) {
            final icons = [
              Icons.home,
              Icons.search,
              Icons.library_music,
              Icons.settings,
            ];
            final isActive = index == _currentIndex;
            return GestureDetector(
              onTap: () {
                if (_showPlaylist) closePlaylist();
                setState(() => _currentIndex = index);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icons[index],
                    color: isActive ? Colors.white : Colors.white54,
                    size: 28,
                  ),
                  const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 20,
                    height: 3,
                    decoration: BoxDecoration(
                      color: isActive ? Colors.blue : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}
