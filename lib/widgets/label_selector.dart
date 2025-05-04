import 'package:flutter/material.dart';

class SelectionScreen extends StatelessWidget {
  const SelectionScreen({super.key, required this.labels});
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pick an option')),
      body: Center(
        child: DropdownMenu(
          requestFocusOnTap: true,
          menuHeight: 200,
          initialSelection: labels,
          controller: TextEditingController(),
          dropdownMenuEntries: List.generate(
            labels.length,
            (i) => DropdownMenuEntry(value: labels[i], label: labels[i]),
          ),
          onSelected: (value) {
            Navigator.pop(context, value);
          },
        ),
      ),
    );
  }
}
