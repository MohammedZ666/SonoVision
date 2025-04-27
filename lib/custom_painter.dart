import 'package:flutter/material.dart';
import 'detection_result.dart';

class BoundingBoxPainter extends CustomPainter {
  final List<DetectionResult> results;

  BoundingBoxPainter(this.results);

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.red
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;

    final textPaint =
        Paint()
          ..color = Colors.red
          ..style = PaintingStyle.fill;

    for (final result in results) {
      final rect = Rect.fromLTRB(
        result.left,
        result.top,
        result.right,
        result.bottom,
      );

      canvas.drawRect(rect, paint);

      // Draw label
      final textSpan = TextSpan(
        text:
            '${result.label} ${(result.confidence * 100).toStringAsFixed(1)}%',
        style: TextStyle(backgroundColor: Colors.red, color: Colors.white),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(result.left, result.top));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
