import 'dart:io';
import 'dart:math' as math;

import 'package:folio/features/chat/data/api_exception.dart';
import 'package:folio/features/reader/data/folio_ai_service.dart';
import 'package:folio/features/sessions/domain/reading_session.dart';
import 'package:pdfrx/pdfrx.dart';

/// One visual text line extracted from a PDF page (testable without a PDF).
class PdfTextLine {
  const PdfTextLine({
    required this.pageNumber,
    required this.text,
    required this.height,
    required this.top,
    required this.left,
  });

  final int pageNumber;
  final String text;
  final double height;
  final double top;
  final double left;
}

/// Offline topic detector: headings = lines taller than typical body text.
class HeadingTopicDetector {
  const HeadingTopicDetector({
    this.heightRatio = 1.30,
    this.minTitleLength = 3,
    this.maxTitleLength = 80,
    this.bodyMinChars = 20,
  });

  final double heightRatio;
  final int minTitleLength;
  final int maxTitleLength;
  final int bodyMinChars;

  Future<TopicDetectionResult> detect({
    required String pdfPath,
    required int fromPage,
    required int toPage,
  }) async {
    final lines = await loadLines(
      pdfPath: pdfPath,
      fromPage: fromPage,
      toPage: toPage,
    );
    if (lines.isEmpty) {
      return TopicDetectionResult.fallback(
        fromPage,
        toPage,
        notes: 'No selectable text in this window.',
      );
    }
    final lastPage = lines.map((l) => l.pageNumber).reduce(math.max);
    return detectFromLines(
      lines,
      fromPage: fromPage,
      toPage: math.min(toPage, lastPage),
    );
  }

  /// Load visual text lines for a page window (shared with TOC detection).
  Future<List<PdfTextLine>> loadLines({
    required String pdfPath,
    required int fromPage,
    required int toPage,
  }) async {
    if (fromPage < 1 || toPage < fromPage) {
      throw ApiException('Enter a valid page range.');
    }
    if (!File(pdfPath).existsSync()) {
      throw ApiException('PDF file is missing. Import again.');
    }

    PdfDocument? doc;
    try {
      doc = await PdfDocument.openFile(pdfPath);
      final pageCount = doc.pages.length;
      if (pageCount == 0) return const [];
      final clampedTo = math.min(toPage, pageCount);
      if (fromPage > pageCount) return const [];

      final lines = <PdfTextLine>[];
      for (var pageNum = fromPage; pageNum <= clampedTo; pageNum++) {
        final page = doc.pages[pageNum - 1];
        final structured = await page.loadStructuredText();
        lines.addAll(linesFromPage(structured));
      }
      return lines;
    } finally {
      await doc?.dispose();
    }
  }

  /// Core heuristic — exposed for unit tests with synthetic lines.
  TopicDetectionResult detectFromLines(
    List<PdfTextLine> lines, {
    required int fromPage,
    required int toPage,
  }) {
    if (lines.isEmpty) {
      return TopicDetectionResult.fallback(
        fromPage,
        toPage,
        notes: 'No selectable text in this window.',
      );
    }

    final bodySize = _estimateBodySize(lines);
    if (bodySize <= 0) {
      return TopicDetectionResult.fallback(
        fromPage,
        toPage,
        notes: 'Could not estimate text size in this window.',
      );
    }

    final threshold = bodySize * heightRatio;
    final candidates = <PdfTextLine>[];
    for (final line in lines) {
      if (line.height < threshold) continue;
      if (!_isPlausibleTitle(line.text)) continue;
      candidates.add(line);
    }

    final headings = _dedupeHeadings(candidates);
    if (headings.isEmpty) {
      return TopicDetectionResult.fallback(
        fromPage,
        toPage,
        notes: 'No larger headings found in this window.',
      );
    }

    final byPage = <int, PdfTextLine>{};
    for (final h in headings) {
      final existing = byPage[h.pageNumber];
      if (existing == null || h.height > existing.height) {
        byPage[h.pageNumber] = h;
      }
    }
    final starts = byPage.values.toList()
      ..sort((a, b) {
        final p = a.pageNumber.compareTo(b.pageNumber);
        if (p != 0) return p;
        return b.top.compareTo(a.top);
      });

    final raw = <DetectedChapter>[];
    for (var i = 0; i < starts.length; i++) {
      final start = starts[i].pageNumber.clamp(fromPage, toPage);
      final end = i + 1 < starts.length
          ? (starts[i + 1].pageNumber - 1).clamp(fromPage, toPage)
          : toPage;
      raw.add(
        DetectedChapter(
          title: _cleanTitle(starts[i].text),
          fromPage: start,
          toPage: end < start ? start : end,
        ),
      );
    }

    return TopicDetectionResult(
      fromPage: fromPage,
      toPage: toPage,
      topics: TopicDetectionResult.normalizeContiguous(raw, fromPage, toPage),
      notes: 'From heading sizes',
    );
  }

  /// Public for TOC facade / tests.
  List<PdfTextLine> linesFromPage(PdfPageText pageText) {
    final fragments = pageText.fragments;
    if (fragments.isEmpty) return const [];

    final sorted = [...fragments]
      ..sort((a, b) {
        final topCmp = b.bounds.top.compareTo(a.bounds.top);
        if (topCmp != 0) return topCmp;
        return a.bounds.left.compareTo(b.bounds.left);
      });

    final lines = <_MutableLine>[];
    for (final f in sorted) {
      final text = f.text;
      if (text.trim().isEmpty) continue;
      final h = _fragmentHeight(f);
      if (h <= 0) continue;

      _MutableLine? match;
      for (final line in lines) {
        final tol = math.max(line.height, h) * 0.55;
        if ((line.top - f.bounds.top).abs() <= tol) {
          match = line;
          break;
        }
      }

      if (match == null) {
        lines.add(
          _MutableLine(
            pageNumber: pageText.pageNumber,
            parts: [text],
            heights: [h],
            top: f.bounds.top,
            left: f.bounds.left,
          ),
        );
      } else {
        match.parts.add(text);
        match.heights.add(h);
        match.left = math.min(match.left, f.bounds.left);
        match.top = (match.top + f.bounds.top) / 2;
      }
    }

    return [
      for (final line in lines)
        PdfTextLine(
          pageNumber: line.pageNumber,
          text: line.parts.join().replaceAll(RegExp(r'\s+'), ' ').trim(),
          height: _median(line.heights),
          top: line.top,
          left: line.left,
        ),
    ]..removeWhere((l) => l.text.isEmpty);
  }

  double _fragmentHeight(PdfPageTextFragment f) {
    if (f.charRects.isNotEmpty) {
      final heights = [
        for (final r in f.charRects)
          if (r.height > 0) r.height,
      ];
      if (heights.isNotEmpty) return _median(heights);
    }
    return f.bounds.height;
  }

  double _estimateBodySize(List<PdfTextLine> lines) {
    final bodyish = [
      for (final l in lines)
        if (l.text.replaceAll(RegExp(r'\s+'), '').length >= bodyMinChars)
          l.height,
    ];
    if (bodyish.isNotEmpty) {
      return _median(bodyish);
    }

    final heights = [for (final l in lines) l.height]..sort();
    if (heights.isEmpty) return 0;
    final lowerCount = math.max(1, (heights.length / 2).ceil());
    return _median(heights.sublist(0, lowerCount));
  }

  bool _isPlausibleTitle(String raw) {
    final text = raw.trim();
    if (text.length < minTitleLength || text.length > maxTitleLength) {
      return false;
    }
    if (RegExp(r'^\d{1,4}$').hasMatch(text)) return false;
    if (RegExp(r'^page\s*\d+$', caseSensitive: false).hasMatch(text)) {
      return false;
    }
    final wordChars = text.replaceAll(
      RegExp(r'[\s\d\.\,\;\:\!\?\-\—\–\(\)\[\]\{\}\"\x27/\\]+'),
      '',
    );
    return wordChars.length >= minTitleLength;
  }

  List<PdfTextLine> _dedupeHeadings(List<PdfTextLine> candidates) {
    if (candidates.isEmpty) return const [];
    final sorted = [...candidates]
      ..sort((a, b) {
        final p = a.pageNumber.compareTo(b.pageNumber);
        if (p != 0) return p;
        return b.top.compareTo(a.top);
      });

    final merged = <PdfTextLine>[];
    for (final c in sorted) {
      if (merged.isEmpty) {
        merged.add(c);
        continue;
      }
      final prev = merged.last;
      final samePage = prev.pageNumber == c.pageNumber;
      final similarHeight =
          (prev.height - c.height).abs() <= prev.height * 0.12;
      final closeVertically =
          samePage && (prev.top - c.top).abs() <= prev.height * 2.2;
      if (samePage && similarHeight && closeVertically) {
        merged[merged.length - 1] = PdfTextLine(
          pageNumber: prev.pageNumber,
          text: '${prev.text} ${c.text}'.trim(),
          height: math.max(prev.height, c.height),
          top: math.max(prev.top, c.top),
          left: math.min(prev.left, c.left),
        );
      } else {
        merged.add(c);
      }
    }
    return merged;
  }

  String _cleanTitle(String text) {
    return text
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[.\s]+$'), '')
        .trim();
  }

  double _median(List<double> values) {
    if (values.isEmpty) return 0;
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid];
    return (sorted[mid - 1] + sorted[mid]) / 2;
  }
}

class _MutableLine {
  _MutableLine({
    required this.pageNumber,
    required this.parts,
    required this.heights,
    required this.top,
    required this.left,
  });

  final int pageNumber;
  final List<String> parts;
  final List<double> heights;
  double top;
  double left;

  double get height => heights.isEmpty
      ? 0
      : heights.reduce((a, b) => a + b) / heights.length;
}
