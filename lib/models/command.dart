/// All the command codes that can be sent and received between [Detector] and
/// [_DetectorServer].
enum Codes { init, busy, ready, detect, result, select }

/// A command sent between [Detector] and [_DetectorServer].
class Command {
  const Command(this.code, {this.args});

  final Codes code;
  final List<Object>? args;
}
