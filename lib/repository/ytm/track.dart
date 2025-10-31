class Track {
  final String title;
  final String artist;
  final String videoId;
  final String? thumbnail;
  final int? durationSec;

  final String? playlistId;
  final bool isPlaylist;

  Track({
    required this.title,
    required this.artist,
    required this.videoId,
    this.thumbnail,
    this.durationSec,
    this.playlistId,
    this.isPlaylist = false,
  });

  factory Track.fromJson(Map<String, dynamic> json) => Track(
    videoId: json['videoId'],
    title: json['title'],
    artist: json['artist'],
    thumbnail: json['thumbnail'],
    durationSec: json['durationSec'],
    isPlaylist: json['isPlaylist'],
    playlistId: json['playlistId'],
  );

  Map<String, dynamic> toJson() => {
    'videoId': videoId,
    'title': title,
    'artist': artist,
    'thumbnail': thumbnail,
    'durationSec': durationSec,
    'isPlaylist': isPlaylist,
    'playlistId': playlistId,
  };

  @override
  String toString() => '$title by $artist ($videoId)';
}
