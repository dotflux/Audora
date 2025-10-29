import 'package:flutter/material.dart';
import 'search_screen.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import '../audio_manager.dart';
import '../audora_music.dart';
import '../widgets/mini_player.dart';
import 'custom_playlist_screen.dart';
import 'package:audio_service/audio_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  late final AudoraClient _client;
  late final AudoraSearch _search;
  late final AudoraPlayer _player;
  late final AudioManager _audioManager;

  bool _showPlaylist = false;
  String? _selectedPlaylist;

  @override
  void initState() {
    super.initState();
    _client = AudoraClient();
    _player = AudoraPlayer(_client);
    _search = AudoraSearch(_client);
    _audioManager = AudioManager(_player);
  }

  final List<IconData> _icons = [
    Icons.home,
    Icons.search,
    Icons.library_music,
    Icons.settings,
  ];

  @override
  Widget build(BuildContext context) {
    final List<Widget> _screens = [
      HomeScreen(search: _search, audioManager: _audioManager),
      SearchScreen(audioManager: _audioManager),
      LibraryScreen(
        playTrack: _audioManager.playTrack,
        onOpenPlaylist: (playlistName) {
          setState(() {
            _selectedPlaylist = playlistName;
            _showPlaylist = true;
          });
        },
      ),
      const Center(
        child: Text("Settings", style: TextStyle(color: Colors.white)),
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Normal navigation stack
          _screens[_currentIndex],

          // CustomPlaylistScreen overlay
          if (_showPlaylist && _selectedPlaylist != null)
            CustomPlaylistScreen(
              playlistName: _selectedPlaylist!,
              playTrack: _audioManager.playTrack,
              onBack: () {
                setState(() {
                  _showPlaylist = false;
                  _selectedPlaylist = null;
                });
              },
            ),

          // Global MiniPlayer
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
                  onNext: _audioManager.skipToNext,
                  onPrevious: _audioManager.skipToPrevious,
                ),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: !_showPlaylist
          ? Container(
              color: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(_icons.length, (index) {
                  final isActive = index == _currentIndex;
                  return GestureDetector(
                    onTap: () => setState(() => _currentIndex = index),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _icons[index],
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
            )
          : null, // hide bottom bar when viewing playlist
    );
  }
}
