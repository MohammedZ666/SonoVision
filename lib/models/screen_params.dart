import 'dart:math';
import 'dart:ui';

/// Singleton to record size related data
class ScreenParams {
  static late Size screenSize;
  static late Size cameraPreviewSize;

  static double previewRatio =
      max(cameraPreviewSize.height, cameraPreviewSize.width) /
      min(cameraPreviewSize.height, cameraPreviewSize.width);

  static Size screenPreviewSize = Size(
    screenSize.width,
    screenSize.width * previewRatio,
  );

  static Size center = Size(
    (screenPreviewSize.width ~/ 2).toDouble(),
    (screenPreviewSize.height ~/ 2).toDouble(),
  );
}
