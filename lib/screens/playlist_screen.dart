import 'package:flutter/material.dart';
import '../audora_music.dart';
import '../audio_manager.dart';
import '../data/custom_playlists.dart';
import '../widgets/add_to_playlist.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../widgets/default_playlist_art.dart';

class PlaylistScreen extends StatefulWidget {
  final String id;
  final String title;
  final bool isCustom;
  final AudioManager audioManager;
  final AudoraSearch search;
  final VoidCallback onBack;

  const PlaylistScreen({
    super.key,
    required this.id,
    required this.title,
    required this.isCustom,
    required this.audioManager,
    required this.search,
    required this.onBack,
  });

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  bool _isLoading = true;
  List<Track> _tracks = [];

  @override
  void initState() {
    super.initState();
    _loadPlaylist();
  }

  Future<void> _loadPlaylist() async {
    try {
      if (widget.isCustom) {
        final customTracks = CustomPlaylists.getTracks(widget.id);
        setState(() {
          _tracks = customTracks;
          _isLoading = false;
        });
      } else {
        final apiTracks = await widget.search.fetchPlaylist(widget.id);
        setState(() {
          _tracks = apiTracks;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load: $e')));
    }
  }

  void _openPlaylistOptions() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF181818),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.white),
                title: const Text(
                  "Edit playlist",
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await _editPlaylist();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                ),
                title: const Text(
                  "Delete playlist",
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await CustomPlaylists.deletePlaylist(widget.id);
                  widget.onBack();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editPlaylist() async {
    final controller = TextEditingController(text: widget.title);
    final picker = ImagePicker();
    String? newCover = CustomPlaylists.getCoverImage(widget.id);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text(
          "Edit Playlist",
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () async {
                final picked = await picker.pickImage(
                  source: ImageSource.gallery,
                );
                if (picked != null) {
                  newCover = picked.path;
                }
              },
              child: CircleAvatar(
                radius: 40,
                backgroundImage: newCover != null
                    ? FileImage(File(newCover!))
                    : null,
                backgroundColor: Colors.white12,
                child: newCover == null
                    ? const Icon(Icons.camera_alt, color: Colors.white70)
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
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
          ],
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
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != widget.title) {
                await CustomPlaylists.renamePlaylist(widget.id, newName);
                widget.onBack();
              }
              if (newCover != null) {
                await CustomPlaylists.setCoverImage(widget.id, newCover);
              }
              if (mounted) setState(() {});
              Navigator.pop(context);
            },
            child: const Text("Save", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _reorderTracks(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;

    setState(() {
      final track = _tracks.removeAt(oldIndex);
      _tracks.insert(newIndex, track);
    });

    await CustomPlaylists.reorderTracks(widget.id, oldIndex, newIndex);
    widget.audioManager.updateQueue(List.from(_tracks));
  }

  Future<void> _removeTrack(String videoId) async {
    await CustomPlaylists.removeTrack(widget.id, videoId);
    setState(() => _tracks.removeWhere((t) => t.videoId == videoId));
  }

  @override
  Widget build(BuildContext context) {
    final customImage = CustomPlaylists.getCoverImage(widget.id);

    final topWidget = _tracks.isNotEmpty && _tracks[0].thumbnail != null
        ? Image.network(_tracks[0].thumbnail!, fit: BoxFit.cover)
        : (customImage != null
              ? Image.file(File(customImage), fit: BoxFit.cover)
              : DefaultPlaylistArt(title: widget.title, size: 140));

    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Stack(
              children: [
                CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverAppBar(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      pinned: true,
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: widget.onBack,
                      ),
                      expandedHeight: 300,
                      flexibleSpace: FlexibleSpaceBar(
                        background: Stack(
                          fit: StackFit.expand,
                          children: [
                            topWidget,
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.9),
                                  ],
                                ),
                              ),
                            ),
                            if (_tracks.isEmpty)
                              Center(
                                child: Image.asset(
                                  'assets/icon/Quaver.png',
                                  width: 120,
                                  height: 120,
                                  color: Colors.transparent,
                                ),
                              ),
                            Positioned(
                              left: 20,
                              bottom: 45,
                              right: 20,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.title,
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${_tracks.length} tracks',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Playlist • ${_tracks.length} tracks",
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 15,
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.play_circle_fill,
                                    color: Colors.white,
                                    size: 36,
                                  ),
                                  onPressed: _tracks.isNotEmpty
                                      ? () => widget.audioManager.playTrack(
                                          _tracks[0],
                                          queue: _tracks,
                                        )
                                      : null,
                                ),
                                if (widget.isCustom)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.more_vert,
                                      color: Colors.white70,
                                    ),
                                    onPressed: _openPlaylistOptions,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    _tracks.isEmpty
                        ? const SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Text(
                                "No tracks here yet",
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          )
                        : SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 100),
                              child: widget.isCustom
                                  ? ReorderableListView.builder(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      onReorder: _reorderTracks,
                                      itemCount: _tracks.length,
                                      proxyDecorator:
                                          (child, index, animation) {
                                            return Material(
                                              color: Colors.black,
                                              elevation: 8,
                                              shadowColor: Colors.black54,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: child,
                                            );
                                          },
                                      itemBuilder: (context, i) {
                                        final track = _tracks[i];
                                        return Container(
                                          key: ValueKey(track.videoId),
                                          color: Colors.transparent,
                                          child: ListTile(
                                            onTap: () =>
                                                widget.audioManager.playTrack(
                                                  track,
                                                  queue: _tracks,
                                                ),
                                            leading: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
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
                                                      color: Colors.white24,
                                                      child: const Icon(
                                                        Icons.music_note,
                                                        color: Colors.white54,
                                                      ),
                                                    ),
                                            ),
                                            title: Text(
                                              track.title,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            subtitle: Text(
                                              track.artist,
                                              style: const TextStyle(
                                                color: Colors.white54,
                                                fontSize: 13,
                                              ),
                                            ),
                                            trailing: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.delete_outline,
                                                    color: Colors.redAccent,
                                                  ),
                                                  onPressed: () => _removeTrack(
                                                    track.videoId,
                                                  ),
                                                ),

                                                ReorderableDragStartListener(
                                                  index: i,
                                                  child: const Padding(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          horizontal: 6.0,
                                                        ),
                                                    child: Icon(
                                                      Icons.drag_handle_rounded,
                                                      color: Colors.white38,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    )
                                  : ListView.builder(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      itemCount: _tracks.length,
                                      itemBuilder: (context, i) {
                                        final track = _tracks[i];
                                        return ListTile(
                                          onTap: () => widget.audioManager
                                              .playTrack(track, queue: _tracks),
                                          leading: ClipRRect(
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
                                                    color: Colors.white24,
                                                    child: const Icon(
                                                      Icons.music_note,
                                                      color: Colors.white54,
                                                    ),
                                                  ),
                                          ),
                                          title: Text(
                                            track.title,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          subtitle: Text(
                                            track.artist,
                                            style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 13,
                                            ),
                                          ),
                                          trailing: IconButton(
                                            icon: const Icon(
                                              Icons.playlist_add,
                                              color: Colors.white70,
                                            ),
                                            onPressed: () {
                                              showModalBottomSheet(
                                                context: context,
                                                isScrollControlled: true,
                                                backgroundColor: const Color(
                                                  0xFF181818,
                                                ),
                                                shape:
                                                    const RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.vertical(
                                                            top:
                                                                Radius.circular(
                                                                  20,
                                                                ),
                                                          ),
                                                    ),
                                                builder: (_) =>
                                                    AddToPlaylistDialog(
                                                      track: track,
                                                    ),
                                              );
                                            },
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ),
                  ],
                ),
              ],
            ),
    );
  }
}
