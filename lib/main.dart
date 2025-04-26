import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:camera/camera.dart';
import 'package:logger/logger.dart';

var logger = Logger(printer: PrettyPrinter());
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late CameraController _controller;
  late List<CameraDescription> _cameras;
  final String modelName = 'yolo11n_float32.tflite';
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _initCameraScreen();
  }

  void _initCameraScreen() async {
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
      ResolutionPreset.max,
      enableAudio: false,
    );
    _controller
        .initialize()
        .then((_) {
          if (!mounted) {
            return;
          }
          setState(() {});
        })
        .catchError((Object e, StackTrace stackTrace) {
          // ✅ Add stack trace parameter
          if (e is CameraException) {
            switch (e.code) {
              case 'CameraAccessDenied':
                logger.e(
                  "Camera permission denied",
                  error: e.description,
                  stackTrace: stackTrace,
                );
                break;
              default:
                logger.e(
                  "Undefined error",
                  error: e.description,
                  stackTrace: stackTrace,
                );
                break;
            }
          }
        });
  }

  Future<void> _loadModel() async {
    try {
      final interpreter = await Interpreter.fromAsset("assets/$modelName");
      var inputShape = interpreter.getInputTensor(0).shape;
      var outputShape = interpreter.getOutputTensor(0).shape;
      var totalInputSize = 1;
      var totalOutputSize = 1;

      for (var i = 0; i < inputShape.length; i++) {
        totalInputSize = totalInputSize * inputShape[i];
      }
      for (var i = 0; i < outputShape.length; i++) {
        totalOutputSize = totalOutputSize * outputShape[i];
      }

      print("$totalInputSize $totalOutputSize");
      var input = List.filled(totalInputSize, 1).reshape(inputShape);
      var output = List.filled(totalOutputSize, 0).reshape(outputShape);

      interpreter.run(input, output);
      logger.i("Model '$modelName' initialized successfully");
    } catch (e, stackTrace) {
      logger.e(
        "Model '$modelName' initialization failed",
        error: e,
        stackTrace: stackTrace,
      );
    }
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
          // CustomPaint(
          //   painter: BoundingBoxPainter(_results),
          //   size: Size.infinite,
          // ),
        ],
      ),
    );
  }
}
