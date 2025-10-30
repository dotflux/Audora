import 'package:flutter/material.dart';
import 'dart:math' as math;

class DefaultPlaylistArt extends StatelessWidget {
  final String title;
  final double size;

  const DefaultPlaylistArt({super.key, required this.title, this.size = 140});

  Color _colorFromTitle() {
    final hash = title.codeUnits.fold(0, (a, b) => a + b);
    final hue = (hash % 360).toDouble();
    return HSLColor.fromAHSL(1, hue, 0.55, 0.45).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = _colorFromTitle();
    final glowColor = baseColor.withValues(alpha: 0.7);
    final bool isSmall = size <= 80;

    final double titleFontSize = isSmall ? size * 0.18 : size * 0.14;
    final double subtitleFontSize = isSmall ? size * 0.10 : size * 0.07;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            Colors.black,
            baseColor.withValues(alpha: 0.4),
            Colors.black,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.5),
            blurRadius: 20,
            spreadRadius: -5,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * 0.8,
            height: size * 0.8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [glowColor.withValues(alpha: 0.35), Colors.transparent],
              ),
            ),
          ),

          CustomPaint(
            size: Size(size * 0.8, size * 0.8),
            painter: _VinylPainter(),
          ),

          Positioned(
            bottom: isSmall ? 10 : 18,
            width: size * 0.9,
            child: Column(
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "AUDORA",
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: subtitleFontSize,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VinylPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final center = Offset(size.width / 2, size.height / 2);
    for (double i = size.width * 0.2; i < size.width / 2; i += 5) {
      canvas.drawCircle(center, i, paint);
    }

    canvas.drawCircle(center, 3, paint..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
