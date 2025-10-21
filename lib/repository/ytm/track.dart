class Track {
  final String title;
  final String artist;
  final String videoId;
  final String? thumbnail;

  Track({
    required this.title,
    required this.artist,
    required this.videoId,
    this.thumbnail,
  });

  @override
  String toString() => '$title by $artist ($videoId)';
}
