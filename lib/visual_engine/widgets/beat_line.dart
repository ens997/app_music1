import 'package:flutter/material.dart';
import '../staff_renderer.dart';

/// Widget que dibuja una línea de beat estática con una ventana de precisión.
class BeatLine extends StatelessWidget {
  final double hitLineX;
  final double staffTop;
  final Color beatColor;
  final double perfectWindowHalfWidth;
  final String label;
  final double lineWidth;

  const BeatLine({
    Key? key,
    required this.hitLineX,
    required this.staffTop,
    required this.beatColor,
    this.perfectWindowHalfWidth = 0,
    this.label = 'BEAT',
    this.lineWidth = 3.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BeatLinePainter(
        hitLineX: hitLineX,
        staffTop: staffTop,
        beatColor: beatColor,
        perfectWindowHalfWidth: perfectWindowHalfWidth,
        label: label,
        lineWidth: lineWidth,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _BeatLinePainter extends CustomPainter {
  final double hitLineX;
  final double staffTop;
  final Color beatColor;
  final double perfectWindowHalfWidth;
  final String label;
  final double lineWidth;

  const _BeatLinePainter({
    required this.hitLineX,
    required this.staffTop,
    required this.beatColor,
    required this.perfectWindowHalfWidth,
    required this.label,
    required this.lineWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width == 0 || size.height == 0) return;

    final staffHeight = 4 * StaffRenderer.SPACE_HEIGHT;

    // Ventana de "perfect" (área sombreada)
    if (perfectWindowHalfWidth > 0) {
      final windowRect = Rect.fromLTRB(
        hitLineX - perfectWindowHalfWidth,
        staffTop,
        hitLineX + perfectWindowHalfWidth,
        staffTop + staffHeight,
      );
      canvas.drawRect(
        windowRect,
        Paint()..color = beatColor.withOpacity(0.12),
      );
    }

    // Línea principal
    canvas.drawLine(
      Offset(hitLineX, staffTop),
      Offset(hitLineX, staffTop + staffHeight),
      Paint()
        ..color = beatColor.withOpacity(0.9)
        ..strokeWidth = lineWidth,
    );

    // Etiqueta
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: beatColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(hitLineX - textPainter.width / 2, 40),
    );
  }

  @override
  bool shouldRepaint(covariant _BeatLinePainter oldDelegate) {
    return oldDelegate.hitLineX != hitLineX ||
        oldDelegate.staffTop != staffTop ||
        oldDelegate.beatColor != beatColor ||
        oldDelegate.perfectWindowHalfWidth != perfectWindowHalfWidth ||
        oldDelegate.label != label ||
        oldDelegate.lineWidth != lineWidth;
  }
}