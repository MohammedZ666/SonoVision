import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'detector_widget.dart';
import 'package:worker_manager/worker_manager.dart';

var logger = Logger(printer: PrettyPrinter());
void main() async {
  workerManager.log = true;
  await workerManager.init();
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
      home: const DetectorWidget(title: 'Detector'),
    );
  }
}
