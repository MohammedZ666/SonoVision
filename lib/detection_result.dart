class DetectionResult {
  final double left;
  final double top;
  final double right;
  final double bottom;
  final String label;
  final confidence;

  DetectionResult({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.label,
    required this.confidence,
  });

  @override
  String toString() {
    // TODO: implement toString
    return "DetectionResult($left,$top,$right,$bottom, $label, $confidence)";
  }
}
