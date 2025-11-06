import 'package:flutter/material.dart';
import '../data/custom_playlists.dart';
import 'package:audora/audora_music.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../widgets/default_playlist_art.dart';
import '../repository/spotify/spotify_api.dart';
import '../repository/spotify/spotify_import.dart';
import 'package:flutter_svg/flutter_svg.dart';

class LibraryScreen extends StatefulWidget {
  final Future<void> Function(Track, {List<Track>? queue}) playTrack;
  final Future<void> Function({
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

  Future<void> _showImportOptions() async {
    final option = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF181818),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Import Playlist',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: SvgPicture.asset(
                'assets/icon/spotify.svg',
                width: 24,
                height: 24,
              ),
              title: const Text(
                'Import from Spotify',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(context, 'spotify'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: SvgPicture.asset(
                'assets/icon/youtube.svg',
                width: 24,
                height: 24,
              ),
              title: const Text(
                'Import from YouTube',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(context, 'youtube'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
        ],
      ),
    );

    if (option == 'spotify') {
      await _importSpotify();
    } else if (option == 'youtube') {
      await _importYouTube();
    }
  }

  Future<void> _importSpotify() async {
    final controller = TextEditingController();

    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text(
          "Import from Spotify",
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Paste playlist URL",
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
            child: const Text("Import", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (url == null || url.isEmpty) return;

    final api = SpotifyApi();
    final importer = SpotifyImporter(api: api, ytmClient: AudoraClient());
    final id = importer.extractPlaylistId(url);
    if (id == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid Spotify playlist URL')),
      );
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Import started...')));
    }

    int done = 0;
    int total = 0;
    final progressKey = GlobalKey<_ProgressDialogState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          _ProgressDialog(key: progressKey, done: done, total: total),
    );

    try {
      await importer.importPlaylist(
        id,
        onProgress: (d, t) {
          done = d;
          total = t;
          progressKey.currentState?.update(d, t);
        },
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      _loadPlaylists();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Import completed')));
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
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

  Future<void> _importYouTube() async {
    final controller = TextEditingController();

    final playlistIdOrUrl = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text(
          "Import from YouTube",
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Paste playlist ID or URL",
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
            child: const Text("Import", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (playlistIdOrUrl == null || playlistIdOrUrl.isEmpty) return;

    String? playlistId;
    if (playlistIdOrUrl.contains('list=')) {
      final match = RegExp(
        r'list=([A-Za-z0-9_-]+)',
      ).firstMatch(playlistIdOrUrl);
      playlistId = match?.group(1);
    } else {
      playlistId = playlistIdOrUrl;
    }

    if (playlistId == null || playlistId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid YouTube playlist ID or URL')),
      );
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Import started...')));
    }

    final progressKey = GlobalKey<_ProgressDialogState>();
    int done = 0;
    int total = 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          _ProgressDialog(key: progressKey, done: done, total: total),
    );

    try {
      final client = AudoraClient();
      final search = AudoraSearch(client);
      final tracks = await search.fetchPlaylist(playlistId, limit: 200);

      if (tracks.isEmpty) {
        if (mounted) Navigator.of(context).pop();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No tracks found in playlist')),
        );
        return;
      }

      total = tracks.length;
      progressKey.currentState?.update(done, total);

      final playlistName =
          'YouTube Playlist ${DateTime.now().millisecondsSinceEpoch}';
      await CustomPlaylists.createPlaylist(playlistName);

      for (final track in tracks) {
        await CustomPlaylists.addTrack(playlistName, track);
        done++;
        progressKey.currentState?.update(done, total);
        await Future.delayed(const Duration(milliseconds: 50));
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      _loadPlaylists();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Import completed')));
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
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
            const SizedBox(width: 6),
            const Icon(Icons.circle, size: 6, color: Colors.white24),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _showImportOptions,
            icon: const Icon(Icons.download, color: Colors.white),
            tooltip: "Import playlist",
          ),
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
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final name = _playlists[index];
                  final trackCount = CustomPlaylists.getTrackCount(name);
                  final cover = CustomPlaylists.getCoverImage(name);
                  final coverFile = cover != null ? File(cover) : null;

                  final coverImage =
                      (coverFile != null && coverFile.existsSync())
                      ? Image.file(
                          coverFile,
                          height: 90,
                          width: 90,
                          fit: BoxFit.cover,
                        )
                      : DefaultPlaylistArt(title: name, size: 90);

                  return InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () async {
                      await widget.openPlaylist(
                        id: name,
                        title: name,
                        isCustom: true,
                      );
                    },
                    child: Container(
                      height: 130,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.6),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: Colors.black.withOpacity(0.45),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: coverImage,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.2,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "$trackCount tracks",
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.white38,
                              size: 26,
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

class _ProgressDialog extends StatefulWidget {
  final int done;
  final int total;

  const _ProgressDialog({super.key, required this.done, required this.total});

  @override
  State<_ProgressDialog> createState() => _ProgressDialogState();
}

class _ProgressDialogState extends State<_ProgressDialog> {
  int done = 0;
  int total = 0;

  @override
  void initState() {
    super.initState();
    done = widget.done;
    total = widget.total;
  }

  void update(int d, int t) {
    if (mounted) {
      setState(() {
        done = d;
        total = t;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.black,
      title: const Text('Importing...', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(
            value: total > 0 ? done / total : null,
            color: Colors.greenAccent,
          ),
          const SizedBox(height: 12),
          Text(
            total == 0 ? 'Preparing...' : 'Imported $done of $total',
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
