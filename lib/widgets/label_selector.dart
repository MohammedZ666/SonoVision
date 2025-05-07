import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tflite/widgets/detector_widget.dart';

class SelectionScreen extends StatefulWidget {
  const SelectionScreen({super.key});

  @override
  State<SelectionScreen> createState() => _SelectionScreenState();
}

class _SelectionScreenState extends State<SelectionScreen> {
  List<String>? _labels;
  late String _detectLabel;
  late String _modelName;
  final List<String> _supportedModels = [
    'yolo11n_float32.tflite',
    'efficientdet-lite2.tflite',
  ];

  @override
  void initState() {
    super.initState();
    _detectLabel = 'tv';
  }

  _loadLabels(String modelName) async {
    final ByteData zipData = await rootBundle.load("assets/${modelName}");
    final Uint8List zipBytes = zipData.buffer.asUint8List();
    final Archive archive = ZipDecoder().decodeBytes(zipBytes);
    logger.i("Attempting to load labels");

    for (final file in archive.files) {
      String content = String.fromCharCodes(file.content);
      if (file.name.contains("label")) {
        setState(() {
          _labels = _extractEfficientdetLabels(content);
        });
      } else if (file.name.contains("meta")) {
        setState(() {
          _labels = _extractYoloLabels(content);
        });
      }
    }
    logger.i("labels loaded -> ${_labels?.length}");
  }

  List<String> _extractYoloLabels(String badJson) {
    badJson = badJson
        .replaceAll("'", "\"") // fix  {0 : 'value',..} -> {0 : "value",..}
        .replaceAllMapped(
          RegExp(r'([{,]\s*)(\d+)(\s*:)'),
          (Match m) =>
              '${m[1]}"${m[2]}"${m[3]}', // fix {0 : "value",..} -> {"0" : "value",..}
        )
        .replaceAll('False', 'false')
        .replaceAll('True', 'true')
        .replaceAll('None', 'null');

    Map<String, dynamic> json = jsonDecode(badJson);
    Map<String, dynamic> names = json['names'] as Map<String, dynamic>;
    return List<String>.from(names.values);
  }

  List<String> _extractEfficientdetLabels(String txtFile) {
    List<String> labels = txtFile.split('\n');
    int count = 0;
    for (var i = 0; i < labels.length; i++) {
      if (labels[i].contains('?')) {
        labels[i] = "undefined$i";
        count++;
      }
    }
    logger.i("Undefined count $count");
    if (labels.last.isEmpty) labels.removeLast();
    return labels;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pick an option')),
      body: Center(
        child: Column(
          spacing: 50,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DropdownMenu(
              requestFocusOnTap: true,
              menuHeight: 200,
              label: Text("Select model"),
              dropdownMenuEntries: List.generate(
                _supportedModels.length,
                (i) => DropdownMenuEntry(
                  value: _supportedModels[i],
                  label: _supportedModels[i],
                ),
              ),
              onSelected: (value) {
                setState(() {
                  _labels = null;
                  _modelName = value!;
                  _loadLabels(value);
                });
              },
            ),
            _labels != null
                ? Column(
                  spacing: 50,
                  children: [
                    DropdownMenu(
                      requestFocusOnTap: true,
                      menuHeight: 200,
                      initialSelection: _labels?[0],
                      label: Text("Total ${_labels?.length} labels"),
                      dropdownMenuEntries: List.generate(
                        (_labels?.length)!,
                        (i) => DropdownMenuEntry(
                          value: (_labels?[i])!,
                          label: (_labels?[i])!,
                        ),
                      ),
                      onSelected: (value) {
                        setState(() {
                          _detectLabel = value!;
                        });
                      },
                    ),
                    ElevatedButton(
                      onPressed:
                          () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder:
                                  (context) => DetectorWidget(
                                    title: ("Detect $_detectLabel"),
                                    modelName: _modelName,
                                    detectLabel: _detectLabel,
                                    labels: _labels!,
                                  ),
                            ),
                          ),
                      child: Text("Detect"),
                    ),
                  ],
                )
                : Container(),
          ],
        ),
      ),
    );
  }
}
