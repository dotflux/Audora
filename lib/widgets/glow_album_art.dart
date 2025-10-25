import 'package:flutter/material.dart';
import 'dart:math';

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
  late AnimationController _controller;

  final double _glowThickness = 5.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) {
        return CustomPaint(
          painter: _GlowBorderPainter(
            animationValue: _controller.value,
            glowThickness: _glowThickness,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: Image.network(
              widget.imageUrl,
              width: widget.size,
              height: widget.size,
              fit: BoxFit.cover,
            ),
          ),
        );
      },
    );
  }
}

class _GlowBorderPainter extends CustomPainter {
  final double animationValue;
  final double glowThickness;

  _GlowBorderPainter({
    required this.animationValue,
    required this.glowThickness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = glowThickness
      ..shader = LinearGradient(
        colors: [Colors.blueAccent, Colors.cyanAccent, Colors.purpleAccent],
        stops: [0.0, 0.5, 1.0],
        transform: GradientRotation(animationValue * 2 * pi),
      ).createShader(rect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(size.width * 0.05),
    );
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _GlowBorderPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}
