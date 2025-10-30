import 'package:flutter/material.dart';
import '../data/custom_playlists.dart';
import 'package:audora/audora_music.dart';
import 'dart:io';
import '../widgets/default_playlist_art.dart';

class LibraryScreen extends StatefulWidget {
  final Future<void> Function(Track, {List<Track>? queue}) playTrack;
  final void Function({
    required String id,
    required String title,
    required bool isCustom,
  })
  openPlaylist;

  const LibraryScreen({
    super.key,
    required this.playTrack,
    required this.openPlaylist,
  });

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<String> _playlists = [];

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  void _loadPlaylists() {
    setState(() {
      _playlists = CustomPlaylists.getPlaylistNames();
    });
  }

  Future<void> _createPlaylist() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text(
          "New Playlist",
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Playlist name",
            hintStyle: TextStyle(color: Colors.white54),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text("Create", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    final success = await CustomPlaylists.createPlaylist(name);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Playlist "$name" already exists')),
      );
    }
    _loadPlaylists();
  }

  Future<void> _deletePlaylist(String name) async {
    await CustomPlaylists.deletePlaylist(name);
    _loadPlaylists();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.86),
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
            const SizedBox(width: 6),
            const Icon(Icons.circle, size: 6, color: Colors.white24),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _createPlaylist,
            icon: const Icon(Icons.add, color: Colors.white),
            tooltip: "Create playlist",
          ),
        ],
      ),
      body: _playlists.isEmpty
          ? const Center(
              child: Text(
                "No playlists yet.\nTap + to create one.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 15),
              ),
            )
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              child: ListView.separated(
                itemCount: _playlists.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final name = _playlists[index];
                  final trackCount = CustomPlaylists.getTracks(name).length;
                  final cover = CustomPlaylists.getCoverImage(name);
                  final coverFile = cover != null ? File(cover) : null;

                  final coverImage =
                      (coverFile != null && coverFile.existsSync())
                      ? Image.file(
                          coverFile,
                          height: 70,
                          width: 70,
                          fit: BoxFit.cover,
                        )
                      : DefaultPlaylistArt(title: name, size: 70);

                  return InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => widget.openPlaylist(
                      id: name,
                      title: name,
                      isCustom: true,
                    ),
                    child: Container(
                      height: 110,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: Colors.black.withOpacity(0.4),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: coverImage,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "$trackCount tracks",
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.white70,
                              ),
                              onPressed: () => _deletePlaylist(name),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
