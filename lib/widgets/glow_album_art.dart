import 'dart:math';
import 'dart:ui' as ui;
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:palette_generator/palette_generator.dart';

class GlowingAlbumArt extends StatefulWidget {
  final String imageUrl;
  final double size;
  final double borderRadius;

  const GlowingAlbumArt({
    super.key,
    required this.imageUrl,
    required this.size,
    required this.borderRadius,
  });

  @override
  State<GlowingAlbumArt> createState() => _GlowingAlbumArtState();
}

class _GlowingAlbumArtState extends State<GlowingAlbumArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  Color _primary = Colors.transparent;
  Color _secondary = Colors.transparent;

  static final Map<String, PalettePair> _paletteCache = {};

  static const double _pad = 28.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensurePalette());
  }

  @override
  void didUpdateWidget(covariant GlowingAlbumArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      setState(() {
        _primary = Colors.transparent;
        _secondary = Colors.transparent;
      });
      _ensurePalette();
    }
  }

  Future<void> _ensurePalette() async {
    final url = widget.imageUrl;
    if (url.isEmpty) return;

    if (_paletteCache.containsKey(url)) {
      final pair = _paletteCache[url]!;
      if (mounted) {
        setState(() {
          _primary = pair.primary;
          _secondary = pair.secondary;
        });
      }
      return;
    }

    try {
      await precacheImage(NetworkImage(url), context);

      final palette = await PaletteGenerator.fromImageProvider(
        NetworkImage(url),
        maximumColorCount: 20,

        size: const Size(200, 200),
        timeout: const Duration(seconds: 2),
      );

      final primary = _pickPrimary(palette);
      final secondary = _pickSecondary(palette, primary);

      final adjustedPrimary = _adjustForGlow(primary);
      final adjustedSecondary = _adjustForGlow(secondary);

      final pair = PalettePair(adjustedPrimary, adjustedSecondary);
      _paletteCache[url] = pair;

      if (mounted) {
        setState(() {
          _primary = adjustedPrimary;
          _secondary = adjustedSecondary;
        });
      }
    } catch (e) {
      final fallbackA = Colors.transparent;
      final fallbackB = Colors.transparent;
      _paletteCache[url] = PalettePair(fallbackA, fallbackB);
      if (mounted) {
        setState(() {
          _primary = fallbackA;
          _secondary = fallbackB;
        });
      }
    }
  }

  Color _pickPrimary(PaletteGenerator p) {
    return p.vibrantColor?.color ??
        p.dominantColor?.color ??
        p.lightVibrantColor?.color ??
        p.mutedColor?.color ??
        (p.paletteColors.isNotEmpty
            ? p.paletteColors.first.color
            : Colors.deepPurpleAccent);
  }

  Color _pickSecondary(PaletteGenerator p, Color primary) {
    final candidates = [
      p.vibrantColor?.color,
      p.darkVibrantColor?.color,
      p.darkMutedColor?.color,
      p.lightVibrantColor?.color,
      p.mutedColor?.color,
    ].whereType<Color>().toList();

    for (final c in candidates) {
      if (_colorDistance(primary, c) > 80) return c;
    }

    for (final pc in p.paletteColors) {
      final c = pc.color;
      if (_colorDistance(primary, c) > 70) return c;
    }

    final h = HSLColor.fromColor(primary);
    final alt = h
        .withHue((h.hue + 60) % 360)
        .withLightness((h.lightness * 0.6).clamp(0.0, 1.0));
    return alt.toColor();
  }

  int _colorDistance(Color a, Color b) {
    return (a.red - b.red).abs() +
        (a.green - b.green).abs() +
        (a.blue - b.blue).abs();
  }

  Color _adjustForGlow(Color c) {
    final h = HSLColor.fromColor(c);
    final sat = (h.saturation * 1.1).clamp(0.0, 1.0);
    final light = h.lightness.clamp(0.12, 0.85);
    return h.withSaturation(sat).withLightness(light).toColor();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalW = widget.size + _pad * 2;
    final totalH = widget.size + _pad * 2;

    return SizedBox(
      width: totalW,
      height: totalH,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final progress = _controller.value;
          return CustomPaint(
            size: Size(totalW, totalH),
            painter: _SnakeGlowPainter(
              progress: progress,
              primary: _primary,
              secondary: _secondary,
              borderRadius: widget.borderRadius,
              imageRect: Rect.fromLTWH(_pad, _pad, widget.size, widget.size),
            ),
            child: Padding(
              padding: const EdgeInsets.all(_pad),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                child: Image.network(
                  widget.imageUrl,
                  width: widget.size,
                  height: widget.size,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class PalettePair {
  final Color primary;
  final Color secondary;
  PalettePair(this.primary, this.secondary);
}

class _SnakeGlowPainter extends CustomPainter {
  final double progress;
  final Color primary;
  final Color secondary;
  final double borderRadius;
  final Rect imageRect;

  _SnakeGlowPainter({
    required this.progress,
    required this.primary,
    required this.secondary,
    required this.borderRadius,
    required this.imageRect,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (primary.alpha == 0 && secondary.alpha == 0) return;

    final rrect = RRect.fromRectAndRadius(
      imageRect,
      Radius.circular(borderRadius),
    );
    final path = Path()..addRRect(rrect);

    final double angle = 2 * pi * progress;

    final colors = <Color>[
      primary.withValues(alpha: 0.0),
      primary.withValues(alpha: 0.25),
      primary.withValues(alpha: 0.95),
      secondary.withValues(alpha: 0.6),
      primary.withValues(alpha: 0.2),
      primary.withValues(alpha: 0.0),
    ];

    final stops = <double>[0.0, 0.45, 0.52, 0.66, 0.82, 1.0];

    final sweep = SweepGradient(
      colors: colors,
      stops: stops,
      transform: GradientRotation(angle),
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(4.0, imageRect.width * 0.032)
      ..shader = sweep.createShader(imageRect.inflate(20))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);

    final haloPaint = paint..strokeWidth = paint.strokeWidth * 3;
    canvas.drawPath(path, haloPaint);

    final innerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = paint.strokeWidth
      ..shader = sweep.createShader(imageRect.inflate(6))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    canvas.drawPath(path, innerPaint);
  }

  @override
  bool shouldRepaint(covariant _SnakeGlowPainter old) {
    return old.progress != progress ||
        old.primary != primary ||
        old.secondary != secondary ||
        old.imageRect != imageRect;
  }
}
