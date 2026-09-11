import 'package:folio/features/sessions/domain/reading_session.dart';
import 'package:folio/features/reader/data/folio_ai_service.dart';

/// Heuristics for when offline TOC results should be refined by AI.
abstract final class TocRefine {
  /// Large leading/body gap without a real TOC title.
  static const int largeGapPages = 30;

  static bool needsRefine(TopicDetectionResult result) {
    final topics = result.topics;
    if (topics.isEmpty) return true;

    for (final t in topics) {
      if (_isPlaceholder(t.title) && _span(t) >= largeGapPages) {
        return true;
      }
    }

    // Chapter numbers jump (e.g. first numbered chapter is 6).
    final numbers = <int>[];
    for (final t in topics) {
      final n = _leadingChapterNumber(t.title);
      if (n != null) numbers.add(n);
    }
    if (numbers.isNotEmpty && numbers.first > 1) return true;
    for (var i = 1; i < numbers.length; i++) {
      if (numbers[i] > numbers[i - 1] + 1) return true;
    }

    // Many glued CamelCase titles (PDF text extraction artifact).
    final glued = topics.where((t) => _looksGlued(t.title)).length;
    if (glued >= 2 && glued >= (topics.length / 2).ceil()) return true;

    return false;
  }

  /// Offline cleanup when AI is unavailable.
  static TopicDetectionResult polishOffline(TopicDetectionResult result) {
    final topics = result.topics.map((t) {
      var title = restoreTitleSpaces(t.title);
      if (_isPlaceholder(title) && t.fromPage == result.fromPage) {
        title = 'Front matter';
      }
      return DetectedChapter(
        title: title,
        fromPage: t.fromPage,
        toPage: t.toPage,
        selected: t.selected,
      );
    }).toList();

    return TopicDetectionResult(
      fromPage: result.fromPage,
      toPage: result.toPage,
      topics: topics,
      notes: result.notes,
    );
  }

  static String restoreTitleSpaces(String title) {
    var t = title.replaceAll(RegExp(r'\s+'), ' ').trim();
    // "6.DecisionTrees" → "6. DecisionTrees"
    t = t.replaceAllMapped(
      RegExp(r'(\d)[.]([A-Za-zÀ-ÿ])'),
      (m) => '${m[1]}. ${m[2]}',
    );
    // "DecisionTrees" → "Decision Trees"
    t = t.replaceAllMapped(
      RegExp(r'([a-zà-ÿ])([A-ZÀ-Ÿ])'),
      (m) => '${m[1]} ${m[2]}',
    );
    // "RNNsand" / "andCNNs" soft fixes are left to AI; keep light offline pass.
    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static bool _isPlaceholder(String title) {
    final n = title.trim().toLowerCase();
    return n.isEmpty ||
        n == 'untitled section' ||
        n == 'untitled' ||
        n == 'front matter';
  }

  static int _span(DetectedChapter t) => t.toPage - t.fromPage + 1;

  static int? _leadingChapterNumber(String title) {
    final m = RegExp(r'^\s*(\d{1,2})[.)\s]').firstMatch(title);
    if (m == null) return null;
    return int.tryParse(m.group(1)!);
  }

  static bool _looksGlued(String title) {
    if (title.contains(' ')) return false;
    return RegExp(r'[a-z][A-Z]').hasMatch(title) ||
        RegExp(r'\d[.][A-Za-z]').hasMatch(title);
  }
}
