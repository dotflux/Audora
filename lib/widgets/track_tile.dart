import 'package:flutter/material.dart';
import '../repository/ytm/track.dart';

class TrackTile extends StatelessWidget {
  final Track track;
  final VoidCallback onTap;

  const TrackTile({super.key, required this.track, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: track.thumbnail != null
          ? Image.network(
              track.thumbnail!,
              width: 50,
              height: 50,
              fit: BoxFit.cover,
            )
          : const SizedBox(width: 50, height: 50),
      title: Text(track.title),
      subtitle: Text(track.artist),
      onTap: onTap,
    );
  }
}
