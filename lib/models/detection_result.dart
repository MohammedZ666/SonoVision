import 'dart:ui';

import 'package:flutter_tflite/models/screen_params.dart';

class DetectionResult {
  final double left;
  final double top;
  final double right;
  final double bottom;
  final String label;
  final confidence;

  DetectionResult({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.label,
    required this.confidence,
  });

  Rect get renderLocation {
    return Rect.fromLTRB(
      left * ScreenParams.screenPreviewSize.width,
      top * ScreenParams.screenPreviewSize.height,
      right * ScreenParams.screenPreviewSize.width,
      bottom * ScreenParams.screenPreviewSize.height,
    );
  }

  @override
  String toString() {
    // TODO: implement toString
    return "DetectionResult($left,$top,$right,$bottom, $label, $confidence)";
  }
}
