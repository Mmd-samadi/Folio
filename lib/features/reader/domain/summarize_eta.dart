import 'dart:math' as math;

/// Heuristic ETA for section summarization (offline estimate).
abstract final class SummarizeEta {
  static const int minSeconds = 5;
  static const int maxSeconds = 180;
  static const int baseSeconds = 8;
  static const double secondsPerPage = 3.5;
  static const double secondsPerMb = 2.0;

  /// Estimate wall time from page span and optional file size in bytes.
  static int estimateSeconds({
    required int fromPage,
    required int toPage,
    int? fileSizeBytes,
  }) {
    final pages = math.max(1, toPage - fromPage + 1);
    var seconds = baseSeconds + pages * secondsPerPage;
    if (fileSizeBytes != null && fileSizeBytes > 0) {
      final mb = fileSizeBytes / (1024 * 1024);
      seconds += mb * secondsPerMb;
    }
    return seconds.round().clamp(minSeconds, maxSeconds);
  }

  static String label(int seconds) {
    if (seconds < 60) return '~${seconds}s';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (s == 0) return '~${m}m';
    return '~${m}m ${s}s';
  }
}
