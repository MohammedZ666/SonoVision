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
  @override
  void initState() {
    super.initState();
    _loadLabels();
    _detectLabel = 'tv';
  }

  _loadLabels() async {
    final ByteData zipData = await rootBundle.load(
      "assets/efficientdet-lite2.tflite",
    );
    final Uint8List zipBytes = zipData.buffer.asUint8List();
    final Archive archive = ZipDecoder().decodeBytes(zipBytes);

    for (final file in archive.files) {
      if (file.name.contains("label")) {
        List<String> labels = String.fromCharCodes(file.content).split('\n');
        for (var i = 0; i < labels.length; i++) {
          if (labels[i].contains('?')) {
            labels[i] = "undefined$i";
          }
        }
        setState(() {
          _labels = labels;
          logger.i("labels loaded");
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pick an option')),
      body: Center(
        child:
            _labels != null
                ? Column(
                  spacing: 50,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    DropdownMenu(
                      requestFocusOnTap: true,
                      menuHeight: 200,
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
                                    modelName: "efficientdet-lite2.tflite",
                                    detectLabel: _detectLabel,
                                    labels: _labels!,
                                  ),
                            ),
                          ),
                      child: Text("Detect"),
                    ),
                  ],
                )
                : Text("Loading ..."),
      ),
    );
  }
}
