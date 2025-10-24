import 'package:flutter/material.dart';
import 'search_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    Center(
      child: Text("Home", style: TextStyle(color: Colors.white)),
    ),
    SearchScreen(),
    Center(
      child: Text("Library", style: TextStyle(color: Colors.white)),
    ),
    Center(
      child: Text("Settings", style: TextStyle(color: Colors.white)),
    ),
  ];

  final List<IconData> _icons = [
    Icons.home,
    Icons.search,
    Icons.library_music,
    Icons.settings,
  ];

  final List<String> _labels = ["Home", "Search", "Library", "Settings"];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        color: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_icons.length, (index) {
            final isActive = index == _currentIndex;
            return GestureDetector(
              onTap: () => setState(() => _currentIndex = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: EdgeInsets.symmetric(
                  horizontal: isActive ? 16 : 0,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isActive ? Colors.blue : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Icon(
                      _icons[index],
                      color: isActive ? Colors.white : Colors.white54,
                      size: 28,
                    ),
                    if (isActive) const SizedBox(width: 8),
                    if (isActive)
                      Text(
                        _labels[index],
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
