/// Thrown when the user cancels an in-flight operation (download / summarize).
class CancelledException implements Exception {
  const CancelledException([this.message = 'Cancelled']);

  final String message;

  @override
  String toString() => message;
}
