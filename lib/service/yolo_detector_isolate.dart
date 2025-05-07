// Copyright 2023 The Flutter team. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as imglib;
import 'package:logger/logger.dart';
import '../utils/image_utils.dart';
import '../../models/detection_result.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter_tflite/models/command.dart';

///////////////////////////////////////////////////////////////////////////////
// **WARNING:** This is not production code and is only intended to be used for
// demonstration purposes.
//
// The following Detector example works by spawning a background isolate and
// communicating with it over Dart's SendPort API. It is presented below as a
// demonstration of the feature "Background Isolate Channels" and shows using
// plugins from a background isolate. The [Detector] operates on the root
// isolate and the [_DetectorServer] operates on a background isolate.
//
// Here is an example of the protocol they use to communicate:
//
//  _________________                         ________________________
//  [:Detector]                               [:_DetectorServer]
//  -----------------                         ------------------------
//         |                                              |
//         |<---------------(init)------------------------|
//         |----------------(init)----------------------->|
//         |<---------------(ready)---------------------->|
//         |                                              |
//         |----------------(detect)--------------------->|
//         |<---------------(busy)------------------------|
//         |<---------------(result)----------------------|
//         |                 . . .                        |
//         |----------------(detect)--------------------->|
//         |<---------------(busy)------------------------|
//         |<---------------(result)----------------------|
//
///////////////////////////////////////////////////////////////////////////////

/// All the command codes that can be sent and received between [DetectorYolo] and
/// [_DetectorServer].

var logger = Logger(printer: PrettyPrinter());

/// A Simple Detector that handles object detection via Service
///
/// All the heavy operations like pre-processing, detection, ets,
/// are executed in a background isolate.
/// This class just sends and receives messages to the isolate.
class DetectorYolo {
  DetectorYolo._(this._isolate, this._interpreter, this._labels);

  final Isolate _isolate;
  late final Interpreter _interpreter;
  late final List<String> _labels;

  List<String> get labels {
    return _labels;
  }

  // To be used by detector (from UI) to send message to our Service ReceivePort
  late final SendPort _sendPort;

  SendPort get sendPort => _sendPort;

  bool _isReady = false;

  // // Similarly, StreamControllers are stored in a queue so they can be handled
  // // asynchronously and serially.
  final StreamController<List<DetectionResult>> resultsStream =
      StreamController<List<DetectionResult>>();

  /// [main] method equivalent of the isolate...
  static Future<DetectorYolo> start(
    String modelName,
    List<String> labels,
  ) async {
    final ReceivePort receivePort = ReceivePort();
    // sendPort - To be used by service Isolate to send message to our ReceiverPort
    final Isolate isolate = await Isolate.spawn(
      _DetectorServer._run,
      receivePort.sendPort,
    );

    final DetectorYolo result = DetectorYolo._(
      isolate,
      await _loadModel(modelName),
      labels,
    );
    receivePort.listen((message) {
      result._handleCommand(message as Command);
    });
    return result;
  }

  static Future<Interpreter> _loadModel(String modelName) async {
    final interpreterOptions = InterpreterOptions();

    // Use XNNPACK Delegate
    if (Platform.isAndroid) {
      interpreterOptions.addDelegate(
        XNNPackDelegate(options: XNNPackDelegateOptions(numThreads: 5)),
      );
    }
    late Interpreter interpreter;
    try {
      interpreter = await Interpreter.fromAsset(
        "assets/$modelName",
        options: interpreterOptions,
      );
    } catch (e, stackTrace) {
      logger.e(
        "Interpreter failed to initialize",
        error: e,
        stackTrace: stackTrace,
      );
    }
    logger.e(
      "${interpreter.getInputTensor(0).shape} \n ${interpreter.getOutputTensor(0).shape}  ",
    );
    return interpreter;
  }

  /// Starts CameraImage processing
  void processFrame(CameraImage cameraImage) {
    if (_isReady) {
      _sendPort.send(Command(Codes.detect, args: [cameraImage]));
    }
  }

  /// Handler invoked when a message is received from the port communicating
  /// with the isolate server.
  void _handleCommand(Command command) {
    switch (command.code) {
      case Codes.init:
        _sendPort = command.args?[0] as SendPort;
        // ----------------------------------------------------------------------
        // Before using platform channels and plugins from background isolates we
        // need to register it with its root isolate. This is achieved by
        // acquiring a [RootIsolateToken] which the background isolate uses to
        // invoke [BackgroundIsolateBinaryMessenger.ensureInitialized].
        // ----------------------------------------------------------------------
        RootIsolateToken rootIsolateToken = RootIsolateToken.instance!;
        _sendPort.send(
          Command(
            Codes.init,
            args: [rootIsolateToken, _interpreter.address, _labels],
          ),
        );
      case Codes.ready:
        _isReady = true;
      case Codes.busy:
        _isReady = false;
      case Codes.result:
        _isReady = true;
        resultsStream.add(command.args?[0] as List<DetectionResult>);
      default:
        debugPrint('Detector unrecognized command: ${command.code}');
    }
  }

  /// Kills the background isolate and its detector server.
  void stop() {
    _isolate.kill();
  }
}

/// The portion of the [DetectorYolo] that runs on the background isolate.
///
/// This is where we use the new feature Background Isolate Channels, which
/// allows us to use plugins from background isolates.
class _DetectorServer {
  /// Result confidence threshold
  Interpreter? _interpreter;
  List<String>? _labels;
  late String _select;

  _DetectorServer(this._sendPort);

  final SendPort _sendPort;

  // ----------------------------------------------------------------------
  // Here the plugin is used from the background isolate.
  // ----------------------------------------------------------------------

  /// The main entrypoint for the background isolate sent to [Isolate.spawn].
  static void _run(SendPort sendPort) {
    ReceivePort receivePort = ReceivePort();
    final _DetectorServer server = _DetectorServer(sendPort);
    receivePort.listen((message) async {
      final Command command = message as Command;
      await server._handleCommand(command);
    });
    // receivePort.sendPort - used by UI isolate to send commands to the service receiverPort
    sendPort.send(Command(Codes.init, args: [receivePort.sendPort]));
  }

  /// Handle the [command] received from the [ReceivePort].
  Future<void> _handleCommand(Command command) async {
    switch (command.code) {
      case Codes.init:
        // ----------------------------------------------------------------------
        // The [RootIsolateToken] is required for
        // [BackgroundIsolateBinaryMessenger.ensureInitialized] and must be
        // obtained on the root isolate and passed into the background isolate via
        // a [SendPort].
        // ----------------------------------------------------------------------
        RootIsolateToken rootIsolateToken =
            command.args?[0] as RootIsolateToken;
        // ----------------------------------------------------------------------
        // [BackgroundIsolateBinaryMessenger.ensureInitialized] for each
        // background isolate that will use plugins. This sets up the
        // [BinaryMessenger] that the Platform Channels will communicate with on
        // the background isolate.
        // ----------------------------------------------------------------------
        BackgroundIsolateBinaryMessenger.ensureInitialized(rootIsolateToken);
        _interpreter = Interpreter.fromAddress(command.args?[1] as int);
        _labels = command.args?[2] as List<String>;
        _select = (_labels?.first)!;
        _sendPort.send(const Command(Codes.ready));
      case Codes.detect:
        _sendPort.send(const Command(Codes.busy));
        final results = _processImage(command.args?[0] as CameraImage);
        _sendPort.send(Command(Codes.result, args: [results]));
      case Codes.select:
        _sendPort.send(const Command(Codes.busy));
        _select = command.args?[0] as String;
        _sendPort.send(const Command(Codes.ready));
      default:
        debugPrint('_DetectorService unrecognized command ${command.code}');
    }
  }

  List<DetectionResult> _processImage(CameraImage cameraImage) {
    if (cameraImage.format.group != ImageFormatGroup.yuv420 &&
        cameraImage.format.group != ImageFormatGroup.bgra8888) {
      throw CameraException(
        "unhandled image format",
        "The Image format is neither yuv420 or bgra8888 ${cameraImage.format.group}",
      );
    }
    late imglib.Image cameraImageRgb;
    if (cameraImage.format.group == ImageFormatGroup.yuv420 &&
        Platform.isAndroid) {
      cameraImageRgb = ImageUtils.convertYUV420ToImage(cameraImage);
    } else if (cameraImage.format.group == ImageFormatGroup.bgra8888 &&
        Platform.isIOS) {
      cameraImageRgb = ImageUtils.convertBGRA8888ToImage(cameraImage);
    } else {
      throw CameraException(
        "Unhandled image format or platform",
        "Image type -> ${cameraImage.format.group}, Platform ${Platform.operatingSystem}",
      );
    }

    if (Platform.isAndroid) {
      cameraImageRgb = imglib.copyRotate(cameraImageRgb, angle: 90);
    }
    final pixels = imglib
        .copyResize(
          cameraImageRgb,
          width: (_interpreter?.getInputTensor(0).shape[2])!,
          height: (_interpreter?.getInputTensor(0).shape[1])!,
        )
        .getBytes(order: imglib.ChannelOrder.rgb)
        .reshape(_interpreter!.getInputTensor(0).shape);

    var outputs = {
      0: [List<List<dynamic>>.filled(300, List<dynamic>.filled(6, 0))],
    };

    try {
      _interpreter!.runForMultipleInputs([pixels], outputs);
    } catch (e, stackTrace) {
      logger.e("Interpreter failed", error: e, stackTrace: stackTrace);
    }
    final results = _parseOutput(
      outputs,
      _interpreter!.getInputTensor(0).shape[1],
      _interpreter!.getInputTensor(0).shape[2],
      cameraImageRgb.width,
      cameraImageRgb.height,
    );
    if (results.isNotEmpty) {
      logger.i(
        "Results, ${results.length}, ${_interpreter!.lastNativeInferenceDurationMicroSeconds / 1000} ms",
      );
    } else {
      logger.e(
        "Results, ${results.length}, ${_interpreter!.lastNativeInferenceDurationMicroSeconds / 1000} ms",
      );
    }
    return results;
  }

  List<DetectionResult> _parseOutput(
    Map<int, List> outputs,
    int modelHeight,
    int modelWidth,
    int originalWidth,
    int originalHeight,
  ) {
    List<List<dynamic>> predictions = outputs[0]![0];
    final results = <DetectionResult>[];
    const confThreshold = 0.5;
    // const iouThreshold = 0.5;
    // const classThreshold = 0.25;

    final scaleX = originalWidth / modelWidth;
    final scaleY = originalHeight / modelHeight;

    for (var i = 0; i < predictions.length; i++) {
      final prediction = predictions[i];

      double confidence = prediction[4];
      if (confidence < confThreshold) continue;

      // Convert bounding box coordinates
      // final cx = prediction[0];
      // final cy = prediction[1];
      // final w = prediction[2];
      // final h = prediction[3];

      final left = prediction[0];
      final top = prediction[1];
      final right = prediction[2];
      final bottom = prediction[3];
      int classId = prediction[5].toInt();

      logger.e("$left $top $right $bottom $classId $confidence");

      results.add(
        DetectionResult(
          left: left,
          top: top,
          right: right,
          bottom: bottom,
          label: _labels![classId],
          confidence: confidence,
        ),
      );
      if (results.length == 5) break;
    }

    return _nonMaxSuppression(results, 0.5);
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
}
