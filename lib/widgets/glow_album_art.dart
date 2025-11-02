import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
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

  Color _primary = const Color(0xFF1F1F1F);
  Color _secondary = const Color(0xFF444444);

  static final Map<String, _PalettePair> _paletteCache = {};

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) => _extractPalette());
  }

  @override
  void didUpdateWidget(covariant GlowingAlbumArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      setState(() {
        _primary = const Color(0xFF1F1F1F);
        _secondary = const Color(0xFF444444);
      });
      _extractPalette();
    }
  }

  Future<void> _extractPalette() async {
    final url = widget.imageUrl;
    if (url.isEmpty) return;

    if (_paletteCache.containsKey(url)) {
      final p = _paletteCache[url]!;
      if (mounted) {
        setState(() {
          _primary = p.primary;
          _secondary = p.secondary;
        });
      }
      return;
    }

    try {
      final uri = Uri.tryParse(url);
      final ImageProvider imageProvider = uri != null && uri.scheme == 'file'
          ? FileImage(File(uri.path))
          : NetworkImage(url) as ImageProvider;

      final palette = await PaletteGenerator.fromImageProvider(
        imageProvider,
        size: const Size(48, 48),
        maximumColorCount: 5,
        timeout: const Duration(milliseconds: 700),
      );

      final rawPrimary =
          palette.vibrantColor?.color ??
          palette.dominantColor?.color ??
          palette.lightVibrantColor?.color ??
          palette.mutedColor?.color;

      final rawSecondary =
          palette.darkVibrantColor?.color ??
          palette.darkMutedColor?.color ??
          (palette.paletteColors.isNotEmpty
              ? palette.paletteColors.first.color
              : null);

      if (rawPrimary != null) {
        final tunedPrimary = _tuneForGlow(rawPrimary);
        final tunedSecondary = rawSecondary != null
            ? _tuneForGlow(rawSecondary)
            : _tuneForGlow(rawPrimary.withAlpha((0.7 * 255).round()));
        _paletteCache[url] = _PalettePair(tunedPrimary, tunedSecondary);
        if (mounted) {
          setState(() {
            _primary = tunedPrimary;
            _secondary = tunedSecondary;
          });
        }
      }
    } catch (_) {}
  }

  Color _tuneForGlow(Color c) {
    final h = HSLColor.fromColor(c);
    final sat = (h.saturation * 1.05).clamp(0.0, 1.0);
    final light = (h.lightness).clamp(0.12, 0.78);
    return h.withSaturation(sat).withLightness(light).toColor();
  }

  Widget _buildImage() {
    final uri = Uri.tryParse(widget.imageUrl);
    if (uri != null && uri.scheme == 'file') {
      return Image.file(
        File(uri.path),
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: widget.size,
          height: widget.size,
          color: Colors.black,
        ),
      );
    }
    return Image.network(
      widget.imageUrl,
      width: widget.size,
      height: widget.size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        width: widget.size,
        height: widget.size,
        color: Colors.black,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final artSize = widget.size;
    final glowSize = artSize * 1.6;
    final stroke = max(3.0, artSize * 0.03);

    return SizedBox(
      width: artSize,
      height: artSize,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final progress = _controller.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: glowSize,
                height: glowSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    widget.borderRadius * 2.0,
                  ),
                  gradient: RadialGradient(
                    center: const Alignment(0, 0),
                    radius: 0.6,
                    colors: [
                      _primary.withAlpha((0.30 * 255).round()),
                      _primary.withAlpha((0.12 * 255).round()),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),

              CustomPaint(
                size: Size(artSize, artSize),
                painter: _SnakeStrokePainter(
                  progress: progress,
                  primary: _primary,
                  secondary: _secondary,
                  cornerRadius: widget.borderRadius,
                  strokeWidth: stroke,
                ),
              ),

              ClipRRect(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                child: _buildImage(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SnakeStrokePainter extends CustomPainter {
  final double progress;
  final Color primary;
  final Color secondary;
  final double cornerRadius;
  final double strokeWidth;

  _SnakeStrokePainter({
    required this.progress,
    required this.primary,
    required this.secondary,
    required this.cornerRadius,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(cornerRadius));
    final path = Path()..addRRect(rrect);

    final angle = 2 * pi * progress;

    final colors = [
      Colors.transparent,

      primary.withAlpha((0.28 * 255).round()),
      primary.withAlpha((0.95 * 255).round()),
      secondary.withAlpha((0.6 * 255).round()),
      primary.withAlpha((0.18 * 255).round()),
      Colors.transparent,
    ];

    final stops = [0.0, 0.40, 0.48, 0.64, 0.82, 1.0];

    final sweep = SweepGradient(
      colors: colors,
      stops: stops,
      transform: GradientRotation(angle),
    );

    final haloPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 2.6
      ..shader = sweep.createShader(rect.inflate(strokeWidth * 6))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);

    canvas.drawPath(path, haloPaint);

    final innerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = sweep.createShader(rect.inflate(strokeWidth))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    canvas.drawPath(path, innerPaint);
  }

  @override
  bool shouldRepaint(covariant _SnakeStrokePainter old) {
    return old.progress != progress ||
        old.primary != primary ||
        old.secondary != secondary ||
        old.strokeWidth != strokeWidth;
  }
}

class _PalettePair {
  final Color primary;
  final Color secondary;
  _PalettePair(this.primary, this.secondary);
}
