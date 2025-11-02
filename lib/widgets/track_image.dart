import 'dart:io';
import 'package:flutter/material.dart';

class TrackImage extends StatelessWidget {
  final String? thumbnail;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const TrackImage({
    super.key,
    required this.thumbnail,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (thumbnail == null || thumbnail!.isEmpty) {
      return placeholder ??
          Container(
            width: width,
            height: height,
            color: Colors.white24,
            child: const Icon(
              Icons.music_note,
              color: Colors.white54,
            ),
          );
    }

    final uri = Uri.tryParse(thumbnail!);
    if (uri != null && uri.scheme == 'file') {
      return Image.file(
        File(uri.path),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) =>
            errorWidget ??
            Container(
              width: width,
              height: height,
              color: Colors.white24,
              child: const Icon(
                Icons.music_note,
                color: Colors.white54,
              ),
            ),
      );
    }

    return Image.network(
      thumbnail!,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) =>
          errorWidget ??
          Container(
            width: width,
            height: height,
            color: Colors.white24,
            child: const Icon(
              Icons.music_note,
              color: Colors.white54,
            ),
          ),
    );
  }
}

