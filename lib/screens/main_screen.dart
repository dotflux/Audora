import 'package:flutter/material.dart';
import 'search_screen.dart';
import 'home_screen.dart';
import '../audio_manager.dart';
import '../audora_music.dart';
import '../widgets/mini_player.dart';
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

  final List<String> _labels = ["Home", "Search", "Library", "Settings"];

  @override
  Widget build(BuildContext context) {
    final List<Widget> _screens = [
      HomeScreen(search: _search, audioManager: _audioManager),
      SearchScreen(audioManager: _audioManager),
      const Center(
        child: Text("Library", style: TextStyle(color: Colors.white)),
      ),
      const Center(
        child: Text("Settings", style: TextStyle(color: Colors.white)),
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _screens[_currentIndex],

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
      ),
    );
  }
}
