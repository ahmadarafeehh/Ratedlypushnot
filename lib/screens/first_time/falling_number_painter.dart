import 'dart:math';
import 'package:flutter/material.dart';
import 'number_particle.dart';

class FallingNumbersPainter extends CustomPainter {
  final List<NumberParticle> particles;
  final TextPainter _textPainter =
      TextPainter(textDirection: TextDirection.ltr);
  final TextStyle _baseStyle = const TextStyle(
    color: Colors.white, // Pure white
    fontWeight: FontWeight.w500, // Increased weight
  );

  FallingNumbersPainter({
    required this.particles,
    required Listenable repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      _textPainter.text = TextSpan(
        text: particle.number.toString(),
        style: _baseStyle.copyWith(
          fontSize: particle.fontSize,
          color: Colors.white
              .withOpacity(particle.opacity * 0.6), // Increased opacity
          shadows: [
            Shadow(
              blurRadius: 2,
              color: Colors.black
                  .withOpacity(0.3), // Add subtle shadow for contrast
            )
          ],
        ),
      );
      _textPainter.layout();

      final offset = Offset(
        particle.x * size.width + sin(particle.sway) * 5,
        particle.y * size.height,
      );

      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      canvas.rotate(particle.rotation);
      _textPainter.paint(canvas, Offset.zero);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(FallingNumbersPainter oldDelegate) => true;
}
