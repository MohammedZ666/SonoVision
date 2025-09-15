import 'package:flutter/material.dart';
import '../models/detection_result.dart';

class BoundingBoxPainter extends CustomPainter {
  final List<DetectionResult> results;

  BoundingBoxPainter(this.results);

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;

    for (final result in results) {
      Color color =
          Colors.primaries[(result.label.length + result.label.codeUnitAt(0)) %
              Colors.primaries.length];
      paint.color = color;

      final rect = result.renderLocation;
      canvas.drawRect(rect, paint);

      // Draw label
      final textSpan = TextSpan(
        text:
            '${result.label} ${(result.confidence * 100).toStringAsFixed(1)}%',
        style: TextStyle(backgroundColor: color, color: Colors.white),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(result.renderLocation.left, result.renderLocation.top),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
