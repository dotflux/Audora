import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import './glow_album_art.dart';
import '../utils/log.dart';

class AlbumArtSection extends StatelessWidget {
  final String imageUrl;
  final double size;

  const AlbumArtSection({super.key, required this.imageUrl, this.size = 340});

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(imageUrl);
    final backgroundImage = uri != null && uri.scheme == 'file'
        ? Image.file(
            File(uri.path),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: Colors.black),
          )
        : Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: Colors.black),
          );
    log.d('imageUrl: $imageUrl');

    return Stack(
      children: [
        Positioned.fill(child: backgroundImage),
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
