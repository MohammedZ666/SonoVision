import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tflite/image_utils.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:logger/logger.dart';
import 'custom_painter.dart';
import 'detection_result.dart';
import 'package:image/image.dart' as imglib;

var logger = Logger(printer: PrettyPrinter());

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late CameraController _controller;
  late List<CameraDescription> _cameras;
  late IsolateInterpreter _isolateInterpreter;
  late Interpreter _interpreter;
  final String modelName = 'yolo11n_int8.tflite';
  bool _isReady = false;
  List<DetectionResult> _results = [];
  late List<int> _inputShape, _outputShape;

  @override
  void initState() {
    super.initState();

    try {
      _initStream();
    } catch (e, stackTrace) {
      logger.e("Error", error: e, stackTrace: stackTrace);
    }
  }

  void _initStream() async {
    await _loadModel();
    await _intializeCamera();
    setState(() {
      _isReady = true;
    });
  }

  Future<void> _intializeCamera() async {
    _cameras = await availableCameras();
    _controller = CameraController(
      _cameras[0],
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await _controller.initialize();
    await _controller.startImageStream(_processImage);
  }

  Future<void> _loadModel() async {
    try {
      var interpreterOptions = InterpreterOptions();

      // Android
      if (Platform.isAndroid) {
        try {
          interpreterOptions.addDelegate(
            GpuDelegateV2(options: GpuDelegateOptionsV2()),
          );
          _interpreter = await Interpreter.fromAsset(
            "assets/$modelName",
            options: interpreterOptions,
          );
          logger.i('GPU Available');
        } catch (e) {
          interpreterOptions = InterpreterOptions();
          interpreterOptions.addDelegate(
            XNNPackDelegate(options: XNNPackDelegateOptions(numThreads: 5)),
          );
          logger.e('GPU not available: $e Falling back to XNNPackDelegate');
        }
      }

      // Use Metal Delegate
      if (Platform.isIOS) {
        interpreterOptions.addDelegate(GpuDelegate());
      }

      try {
        _interpreter = await Interpreter.fromAsset(
          "assets/$modelName",
          options: interpreterOptions,
        );
      } catch (e, stackTrace) {
        logger.e(
          "GPU for IoS/XNNPack delegation failed. falling back to default options",
          stackTrace: stackTrace,
          error: e,
        );

        _interpreter = await Interpreter.fromAsset("assets/$modelName");
      }

      _inputShape = _interpreter.getInputTensor(0).shape;
      _outputShape = _interpreter.getOutputTensor(0).shape;
      var totalInputSize = 1;
      var totalOutputSize = 1;

      for (var i = 0; i < _inputShape.length; i++) {
        totalInputSize = totalInputSize * _inputShape[i];
      }
      for (var i = 0; i < _outputShape.length; i++) {
        totalOutputSize = totalOutputSize * _outputShape[i];
      }

      logger.e("Shapes $_inputShape -> $_outputShape");

      var input = List.filled(totalInputSize, 1).reshape(_inputShape);
      var output = List.filled(totalOutputSize, 0).reshape(_outputShape);

      _interpreter.run(input, output);
      _isolateInterpreter = await IsolateInterpreter.create(
        address: _interpreter.address,
      );
      logger.i("Model '$modelName' initialized successfully");
    } catch (e, stackTrace) {
      logger.e(
        "Model '$modelName' initialization failed",
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  void _processImage(CameraImage cameraImage) async {
    if (cameraImage.format.group != ImageFormatGroup.yuv420 &&
        cameraImage.format.group != ImageFormatGroup.bgra8888) {
      throw CameraException(
        "unhandled image format",
        "The Image format is neither yuv420 or bgra8888 ${cameraImage.format.group}",
      );
    }
    imglib.Image image =
        cameraImage.format.group == ImageFormatGroup.yuv420
            ? ImageUtils.convertYUV420ToImage(cameraImage)
            : ImageUtils.convertBGRA8888ToImage(cameraImage);

    final resizedImage = imglib.copyResize(
      image,
      width: _inputShape[1],
      height: _inputShape[2],
    );
    final pixels = resizedImage.getBytes(order: imglib.ChannelOrder.rgb);

    List input = Float32List(pixels.length);

    for (var i = 0; i < pixels.length; i++) {
      input[i] = pixels[i] / 255.0;
    }
    input = input.reshape(_inputShape);
    final output = List.filled(
      _outputShape[1] * _outputShape[2],
      0.0,
    ).reshape(_outputShape);

    await _isolateInterpreter.run(input, output);
    final results = _parseOutput(output, image.width, image.height);
    logger.e("Results, ${results.first.toString()}");
    setState(() => _results = results);
  }

  List<DetectionResult> _parseOutput(
    List<dynamic> output,
    int originalWidth,
    int originalHeight,
  ) {
    // YOLOv8 output format: [1, 8400, 85]
    final predictions = output[0] as List<List<double>>;
    final results = <DetectionResult>[];
    const confThreshold = 0.5;
    // const iouThreshold = 0.5;
    // const classThreshold = 0.25;

    final scaleX = originalWidth / _inputShape[1];
    final scaleY = originalHeight / _inputShape[2];

    for (final prediction in predictions) {
      final confidence = prediction[4];

      if (confidence < confThreshold) continue;

      final classId = prediction[5].toInt();
      ;
      // var maxScore = 0.0;
      // for (var i = 5; i < prediction.length; i++) {
      //   final score = prediction[i] * confidence;
      //   if (score > maxScore) {
      //     maxScore = score;
      //     classId = i - 5;
      //   }
      // }

      // // Skip low class confidence
      // if (maxScore < classThreshold) continue;

      // Convert bounding box coordinates
      final cx = prediction[0] * _inputShape[1] * scaleX;
      final cy = prediction[1] * _inputShape[2] * scaleY;
      final w = prediction[2] * _inputShape[1] * scaleX;
      final h = prediction[3] * _inputShape[2] * scaleY;

      final left = cx - w / 2;
      final top = cy - h / 2;
      final right = cx + w / 2;
      final bottom = cy + h / 2;

      results.add(
        DetectionResult(
          left: left,
          top: top,
          right: right,
          bottom: bottom,
          label: classId.toString(),
          confidence: prediction[4],
        ),
      );
    }

    return results;

    // return _nonMaxSuppression(results, iouThreshold);
  }

  List<DetectionResult> _nonMaxSuppression(
    List<DetectionResult> results,
    double iouThreshold,
  ) {
    results.sort((a, b) => b.confidence.compareTo(a.confidence));

    final selected = <DetectionResult>[];
    final suppressed = List<bool>.filled(results.length, false);

    for (var i = 0; i < results.length; i++) {
      if (suppressed[i]) continue;
      selected.add(results[i]);

      for (var j = i + 1; j < results.length; j++) {
        if (suppressed[j]) continue;

        final iou = _calculateIoU(results[i], results[j]);
        if (iou > iouThreshold) {
          suppressed[j] = true;
        }
      }
    }

    return selected;
  }

  // Intersection over Union calculation
  double _calculateIoU(DetectionResult a, DetectionResult b) {
    final interLeft = a.left > b.left ? a.left : b.left;
    final interTop = a.top > b.top ? a.top : b.top;
    final interRight = a.right < b.right ? a.right : b.right;
    final interBottom = a.bottom < b.bottom ? a.bottom : b.bottom;

    if (interRight < interLeft || interBottom < interTop) return 0.0;

    final interArea = (interRight - interLeft) * (interBottom - interTop);
    final areaA = (a.right - a.left) * (a.bottom - a.top);
    final areaB = (b.right - b.left) * (b.bottom - b.top);

    return interArea / (areaA + areaB - interArea);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) return Container();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Stack(
        children: [
          CameraPreview(_controller),
          CustomPaint(
            painter: BoundingBoxPainter(_results),
            size: Size.infinite,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _interpreter.close();
    _isolateInterpreter.close();
    super.dispose();
  }
}
