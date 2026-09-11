import 'package:folio/features/import/data/heading_topic_detector.dart';
import 'package:folio/features/import/data/toc_refine.dart';
import 'package:folio/features/reader/data/folio_ai_service.dart';
import 'package:folio/features/sessions/domain/reading_session.dart';

/// Result of offline TOC parsing, including raw material for AI refine.
class TocAnalysis {
  const TocAnalysis({
    required this.sections,
    required this.candidates,
    required this.rawTocText,
  });

  final TopicDetectionResult sections;
  final List<({String title, int page})> candidates;
  final String rawTocText;

  List<Map<String, dynamic>> get candidatesJson => [
        for (final c in candidates)
          {'title': c.title, 'startPage': c.page},
      ];
}

/// Offline TOC parser — pure logic, unit-testable without PDF I/O.
///
/// Assumption: TOC page numbers are treated as absolute PDF page indices
/// (same numbering as pdfrx). Printed front-matter offsets are not remapped
/// offline; AI refine may infer an offset from multiple anchors.
class TocSectionDetector {
  const TocSectionDetector({
    this.minEntries = 2,
    this.maxTocScanPages = 80,
  });

  final int minEntries;
  final int maxTocScanPages;

  static final _tocKeywords = RegExp(
    r'(table\s+of\s+contents|\bcontents\b|فهرست(\s+مطالب)?|فهرست\s+موضوعات)',
    caseSensitive: false,
  );

  /// Matches "Title ..... 12" / "Title  12" / "Title\t۱۲"
  static final _entryPattern = RegExp(
    r'^(?<title>.+?)(?:[\s\.·•…]{2,}|\s{2,}|\t+)(?<page>\d{1,4}|[\u06F0-\u06F9]{1,4}|[\u0660-\u0669]{1,4})\s*$',
  );

  /// Try to build topics from TOC-like lines. Returns null if TOC not found.
  TopicDetectionResult? detectFromLines(
    List<PdfTextLine> lines, {
    required int fromPage,
    required int toPage,
  }) {
    return analyzeFromLines(
      lines,
      fromPage: fromPage,
      toPage: toPage,
    )?.sections;
  }

  /// Full TOC analysis for hybrid offline + AI refine.
  TocAnalysis? analyzeFromLines(
    List<PdfTextLine> lines, {
    required int fromPage,
    required int toPage,
  }) {
    if (lines.isEmpty) return null;

    final scanUntil = _tocScanEnd(fromPage, toPage);
    final early = lines.where((l) => l.pageNumber <= scanUntil).toList();
    if (early.isEmpty) return null;

    final tocPages = _findTocPages(early);
    final candidateLines = tocPages.isEmpty
        ? early
        : early.where((l) => tocPages.contains(l.pageNumber)).toList();

    final entries = <({String title, int page})>[];
    for (final line in candidateLines) {
      final parsed = parseTocLine(line.text);
      if (parsed == null) continue;
      if (parsed.page < fromPage || parsed.page > toPage) continue;
      if (parsed.title.length < 3) continue;
      entries.add(parsed);
    }

    // Dedupe by page keeping first title.
    final byPage = <int, String>{};
    for (final e in entries) {
      byPage.putIfAbsent(e.page, () => e.title);
    }

    if (byPage.length < minEntries) return null;

    final starts = byPage.keys.toList()..sort();
    final candidates = <({String title, int page})>[
      for (final p in starts) (title: byPage[p]!, page: p),
    ];

    final raw = <DetectedChapter>[];
    for (var i = 0; i < starts.length; i++) {
      final start = starts[i];
      final end = i + 1 < starts.length ? starts[i + 1] - 1 : toPage;
      raw.add(
        DetectedChapter(
          title: TocRefine.restoreTitleSpaces(_cleanTitle(byPage[start]!)),
          fromPage: start,
          toPage: end < start ? start : end,
        ),
      );
    }

    final sections = TopicDetectionResult(
      fromPage: fromPage,
      toPage: toPage,
      topics: TopicDetectionResult.normalizeContiguous(raw, fromPage, toPage),
      notes: 'From table of contents',
    );

    final pagesForText =
        tocPages.isEmpty ? early.map((l) => l.pageNumber).toSet() : tocPages;
    final rawTocText = _buildRawTocText(lines, pagesForText);

    return TocAnalysis(
      sections: TocRefine.polishOffline(sections),
      candidates: candidates,
      rawTocText: rawTocText,
    );
  }

  /// Public for tests.
  ({String title, int page})? parseTocLine(String raw) {
    final text = raw.trim();
    if (text.length < 5) return null;
    if (_tocKeywords.hasMatch(text) && !_entryPattern.hasMatch(text)) {
      return null;
    }

    final match = _entryPattern.firstMatch(text);
    if (match == null) return null;

    var title = (match.namedGroup('title') ?? '').trim();
    title = title.replaceAll(RegExp(r'[\.\s·•…]+$'), '').trim();
    final pageRaw = match.namedGroup('page') ?? '';
    final page = _parsePageNumber(pageRaw);
    if (page == null || page < 1) return null;
    if (title.length < 3) return null;
    return (title: title, page: page);
  }

  bool looksLikeTocHeading(String text) => _tocKeywords.hasMatch(text.trim());

  int _tocScanEnd(int fromPage, int toPage) {
    final span = toPage - fromPage + 1;
    // Prefer a wider early window for long TOCs (multi-page Contents).
    final byPct = fromPage + (span * 0.20).ceil();
    final capped = fromPage + maxTocScanPages - 1;
    final end = byPct < capped ? byPct : capped;
    return end.clamp(fromPage, toPage);
  }

  Set<int> _findTocPages(List<PdfTextLine> early) {
    final pages = <int>{};
    for (final line in early) {
      if (looksLikeTocHeading(line.text)) {
        pages.add(line.pageNumber);
        // TOC often spans several pages after the heading.
        for (var d = 1; d <= 6; d++) {
          pages.add(line.pageNumber + d);
        }
      }
    }
    final counts = <int, int>{};
    for (final line in early) {
      if (parseTocLine(line.text) != null) {
        counts[line.pageNumber] = (counts[line.pageNumber] ?? 0) + 1;
      }
    }
    for (final e in counts.entries) {
      if (e.value >= 3) pages.add(e.key);
    }
    return pages;
  }

  String _buildRawTocText(List<PdfTextLine> lines, Set<int> pages) {
    final sorted = lines.where((l) => pages.contains(l.pageNumber)).toList()
      ..sort((a, b) {
        final byPage = a.pageNumber.compareTo(b.pageNumber);
        if (byPage != 0) return byPage;
        return b.top.compareTo(a.top);
      });

    final buf = StringBuffer();
    var lastPage = -1;
    for (final line in sorted) {
      if (line.pageNumber != lastPage) {
        if (buf.isNotEmpty) buf.writeln();
        buf.writeln('--- PDF page ${line.pageNumber} ---');
        lastPage = line.pageNumber;
      }
      final t = line.text.trim();
      if (t.isEmpty) continue;
      buf.writeln(t);
      if (buf.length > 28000) {
        buf.writeln('…[truncated]');
        break;
      }
    }
    return buf.toString();
  }

  int? _parsePageNumber(String raw) {
    final buf = StringBuffer();
    for (final r in raw.runes) {
      final ch = String.fromCharCode(r);
      if (r >= 0x06F0 && r <= 0x06F9) {
        buf.write(r - 0x06F0);
      } else if (r >= 0x0660 && r <= 0x0669) {
        buf.write(r - 0x0660);
      } else if (r >= 0x30 && r <= 0x39) {
        buf.write(ch);
      }
    }
    return int.tryParse(buf.toString());
  }

  String _cleanTitle(String title) {
    return title.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
