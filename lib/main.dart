import 'package:flutter/material.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:logger/logger.dart';
import 'widgets/detector_widget.dart';
import 'package:worker_manager/worker_manager.dart';
import 'models/screen_params.dart';

var logger = Logger(printer: PrettyPrinter());
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  workerManager.log = true;
  await workerManager.init();
  await SoLoud.instance.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    ScreenParams.screenSize = MediaQuery.sizeOf(context);

    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const DetectorWidget(title: 'Detector'),
    );
  }
}
