import 'dart:ui';
import 'package:flutter/material.dart';
import './glow_album_art.dart';

class AlbumArtSection extends StatelessWidget {
  final String imageUrl;
  final double size;

  const AlbumArtSection({super.key, required this.imageUrl, this.size = 340});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: Image.network(imageUrl, fit: BoxFit.cover)),
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
            child: Container(color: const Color.fromRGBO(0, 0, 0, 0.55)),
          ),
        ),
        Center(
          child: GlowingAlbumArt(
            imageUrl: imageUrl,
            size: size,
            borderRadius: 16,
          ),
        ),
      ],
    );
  }
}
