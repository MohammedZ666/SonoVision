import 'dart:async';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tflite/service/detector_isolate.dart';
import 'package:flutter_tflite/models/screen_params.dart';
import 'package:logger/logger.dart';
import 'custom_painter.dart';
import '../models/detection_result.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:vector_math/vector_math.dart';

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
  double p = 10;
  late SoundHandle _handle;
  late AudioSource _tone;
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
    // Create a sine wave at 440 Hz (A4 note)
    // final tone = await SoLoud.instance.loadWaveform(
    //   WaveForm.sin,
    //   false,
    //   1.0,
    //   0.0,
    // );

    _tone = await SoLoud.instance.loadAsset("assets/sin_125Hz_-3dBFS_2s.wav");

    // Play the tone
    _handle = await SoLoud.instance.play3d(
      _tone,
      0,
      0,
      0,
      velX: 0.0, // optional velocity
      velY: 0.0,
      velZ: 0.0,
      looping: true,
    );
    SoLoud.instance.setPause(_handle, true);

    FlutterCompass.events?.listen((CompassEvent event) {
      if (event.heading != null) {
        double heading =
            event.heading! * pi / 180; // Convert degrees to radians
        // Assuming z-forward, y-up coordinate system
        Vector3 at = Vector3(cos(heading), 0, sin(heading)); // Direction facing
        Vector3 up = Vector3(0, 1, 0); // Up direction

        SoLoud.instance.set3dListenerAt(at.x, at.y, at.z); // Facing direction
        SoLoud.instance.set3dListenerUp(up.x, up.y, up.z); // Up vector
      }
    });
    logger.e("tone called");
  }

  void _updateSoundCueDirection() {
    _locX = _results[0].renderLocation.center.dx - ScreenParams.center.width;
    _locY = _results[0].renderLocation.center.dy - ScreenParams.center.height;
    SoLoud.instance.set3dSourcePosition(_handle, _locX, _locY, 0);
    SoLoud.instance.setPause(_handle, false);
    //   if (SoLoud.instance.getPause(_handle)) {
    //     SoLoud.instance.play(_tone, looping: true);
    // if (_results.isNotEmpty) {
    //   locX = _results[0].renderLocation.center.dx - ScreenParams.center.width;
    //   locY = _results[0].renderLocation.center.dy - ScreenParams.center.height;
    //   SoLoud.instance.set3dSourcePosition(_handle, locX, locY, 0);
    //   if (SoLoud.instance.getPause(_handle)) {
    //     SoLoud.instance.play(_tone, looping: true);
    //   }
    // } else {
    //   if (!SoLoud.instance.getPause(_handle)) {
    //     SoLoud.instance.pauseSwitch(_handle);
    //   }
    // }
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
            if (values.isNotEmpty) {
              _updateSoundCueDirection();
            } else {
              SoLoud.instance.setPause(_handle, true);
            }
          });
        });
      });
    });
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
      body: Stack(
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
