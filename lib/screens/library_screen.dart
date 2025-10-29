import 'package:flutter/material.dart';
import '../data/custom_playlists.dart';
import 'package:audora/audora_music.dart';

class LibraryScreen extends StatefulWidget {
  final Future<void> Function(Track, {List<Track>? queue}) playTrack;
  final void Function(String playlistName)? onOpenPlaylist;

  const LibraryScreen({
    super.key,
    required this.playTrack,
    this.onOpenPlaylist,
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
        backgroundColor: Colors.black,
        title: const Text("Library", style: TextStyle(color: Colors.white)),
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
          : ListView.builder(
              itemCount: _playlists.length,
              itemBuilder: (context, index) {
                final name = _playlists[index];
                return ListTile(
                  title: Text(
                    name,
                    style: const TextStyle(color: Colors.white, fontSize: 17),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.white54),
                    onPressed: () => _deletePlaylist(name),
                  ),
                  onTap: () {
                    widget.onOpenPlaylist?.call(name);
                  },
                );
              },
            ),
    );
  }
}
