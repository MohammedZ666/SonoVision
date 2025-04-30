import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tflite/detector_isolate.dart';
import 'package:logger/logger.dart';
import 'custom_painter.dart';
import 'detection_result.dart';

var logger = Logger(printer: PrettyPrinter());

class DetectorWidget extends StatefulWidget {
  const DetectorWidget({super.key, required this.title});
  final String title;

  @override
  State<DetectorWidget> createState() => _DetectorWidgetState();
}

class _DetectorWidgetState extends State<DetectorWidget>
    with WidgetsBindingObserver {
  late CameraController _cameraController;
  final String modelName = 'efficientdet-lite2.tflite';
  bool _isReady = false;
  List<DetectionResult> _results = [];
  Detector? _detector;
  late StreamSubscription _subscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    try {
      _initStream();
    } catch (e, stackTrace) {
      logger.e("Error", error: e, stackTrace: stackTrace);
    }
  }

  void _initStream() async {
    await _intializeCamera();
    Detector.start().then((instance) {
      setState(() {
        _detector = instance;
        _subscription = instance.resultsStream.stream.listen((
          List<DetectionResult> values,
        ) {
          setState(() {
            _results = values;
            _isReady = true;
          });
        });
      });
    });
  }

  Future<void> _intializeCamera() async {
    List<CameraDescription> cameras = await availableCameras();
    _cameraController = CameraController(
      cameras[0],
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await _cameraController.initialize();
    await _cameraController.startImageStream(onLatestIFrameAvailable);
  }

  void onLatestIFrameAvailable(CameraImage cameraImage) {
    _detector?.processFrame(cameraImage);
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
          CameraPreview(_cameraController),
          CustomPaint(
            painter: BoundingBoxPainter(_results),
            size: Size.infinite,
          ),
        ],
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.inactive:
        _cameraController.stopImageStream();
        _detector?.stop();
        _subscription.cancel();
        break;
      case AppLifecycleState.resumed:
        _initStream();
        break;
      default:
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _detector?.stop();
    _subscription?.cancel();
    super.dispose();
  }
}
