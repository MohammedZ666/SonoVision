import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tflite/service/detector_isolate.dart';
import 'package:flutter_tflite/models/screen_params.dart';
import 'package:logger/logger.dart';
import 'custom_painter.dart';
import '../models/detection_result.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter_tflite/service/yolo_detector_isolate.dart';
import 'package:flutter_tflite/models/command.dart';

var logger = Logger(printer: PrettyPrinter());

class DetectorWidget extends StatefulWidget {
  const DetectorWidget({
    super.key,
    required this.title,
    required this.modelName,
    required this.detectLabel,
    required this.labels,
  });
  final String title;
  final String modelName;
  final String detectLabel;
  final List<String> labels;

  @override
  State<DetectorWidget> createState() => _DetectorWidgetState();
}

class _DetectorWidgetState extends State<DetectorWidget>
    with WidgetsBindingObserver {
  late CameraController _cameraController;
  bool _isReady = false;
  List<DetectionResult> _results = [];
  var _detector;
  late StreamSubscription _subscription;
  late SoundHandle _handle;
  double _locX = 0.0;
  double _locY = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    try {
      _initStream();
      _initSoundCue();
    } catch (e, stackTrace) {
      logger.e("Error", error: e, stackTrace: stackTrace);
    }
  }

  void _initSoundCue() async {
    final tone = await SoLoud.instance.loadWaveform(
      WaveForm.square,
      false,
      1.0,
      0.0,
    );
    SoLoud.instance.setWaveformFreq(tone, 125);
    _handle = await SoLoud.instance.play3d(
      tone,
      0,
      0,
      0,
      velX: 0.0,
      velY: 0.0,
      velZ: 0.0,
      volume: 0.5,
      looping: true,
    );
    SoLoud.instance.setPause(_handle, true);
    logger.e("tone called");
  }

  void _updateSoundCueDirection() {
    _locX = _results[0].renderLocation.center.dx - ScreenParams.center.width;
    _locY = _results[0].renderLocation.center.dy - ScreenParams.center.height;
    SoLoud.instance.set3dSourcePosition(_handle, _locX, _locY, 0);
    SoLoud.instance.setPause(_handle, false);
  }

  void _initStream() async {
    await _intializeCamera();
    if (widget.modelName.contains('yolo')) {
      logger.e('in the yolo part');
      DetectorYolo.start(widget.modelName, widget.labels).then((instance) {
        setState(() {
          _detector = instance;
          _subscription = instance.resultsStream.stream.listen((
            List<DetectionResult> values,
          ) {
            setState(() {
              _results = values;
              _isReady = true;
              if (values.isNotEmpty) {
                _updateSoundCueDirection();
              } else {
                SoLoud.instance.setPause(_handle, true);
              }
            });
            _detector?.sendPort.send(
              Command(Codes.select, args: [widget.detectLabel]),
            );
          });
        });
      });
    } else {
      Detector.start(widget.modelName, widget.labels).then((instance) {
        setState(() {
          _detector = instance;
          _subscription = instance.resultsStream.stream.listen((
            List<DetectionResult> values,
          ) {
            setState(() {
              _results = values;
              _isReady = true;
              if (values.isNotEmpty) {
                _updateSoundCueDirection();
              } else {
                SoLoud.instance.setPause(_handle, true);
              }
            });
            _detector?.sendPort.send(
              Command(Codes.select, args: [widget.detectLabel]),
            );
          });
        });
      });
    }
  }

  Future<void> _intializeCamera() async {
    List<CameraDescription> cameras = await availableCameras();
    _cameraController = CameraController(
      cameras[0],
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await _cameraController.initialize();
    await _cameraController.startImageStream(onLatestIFrameAvailable);
    setState(() {});
    ScreenParams.cameraPreviewSize = _cameraController.value.previewSize!;
    logger.e(
      "Camera Preview size ${ScreenParams.cameraPreviewSize} Screen size ${ScreenParams.screenSize}",
    );
  }

  void onLatestIFrameAvailable(CameraImage cameraImage) {
    _detector?.processFrame(cameraImage);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) return Container();

    var aspect = 1 / _cameraController.value.aspectRatio;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,

        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: aspect,
                child: CameraPreview(_cameraController),
              ),
              AspectRatio(
                aspectRatio: aspect,
                child: CustomPaint(
                  painter: BoundingBoxPainter(_results),
                  size: Size.infinite,
                ),
              ),
            ],
          ),

          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Choose new label"),
          ),

          Text("Currently detecting label \"${widget.detectLabel}\""),
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
    _cameraController.dispose();
    _detector?.stop();
    _subscription.cancel();
    SoLoud.instance.disposeAllSources();
    super.dispose();
  }
}
