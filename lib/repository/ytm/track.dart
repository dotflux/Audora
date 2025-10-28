class Track {
  final String title;
  final String artist;
  final String videoId;
  final String? thumbnail;

  final String? playlistId;
  final bool isPlaylist;

  Track({
    required this.title,
    required this.artist,
    required this.videoId,
    this.thumbnail,
    this.playlistId,
    this.isPlaylist = false,
  });

  @override
  String toString() => '$title by $artist ($videoId)';
}
