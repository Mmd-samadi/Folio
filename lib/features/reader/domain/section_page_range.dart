import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

/// Helpers for restricting a PDF viewer to a Folio section page span.
abstract final class SectionPageRange {
  /// Clamps [page] into the inclusive section window.
  static int clampPage(int page, int fromPage, int toPage) {
    final lo = math.min(fromPage, toPage);
    final hi = math.max(fromPage, toPage);
    if (page < lo) return lo;
    if (page > hi) return hi;
    return page;
  }

  /// Absolute page label, e.g. `33 / 35` (current / section end).
  static String pageLabel(int page, int fromPage, int toPage) {
    final lo = math.min(fromPage, toPage);
    final hi = math.max(fromPage, toPage);
    final p = clampPage(page, lo, hi);
    return '$p / $hi';
  }

  /// Whether [page] is inside the section window.
  static bool contains(int page, int fromPage, int toPage) {
    final lo = math.min(fromPage, toPage);
    final hi = math.max(fromPage, toPage);
    return page >= lo && page <= hi;
  }

  /// pdfrx layout that only stacks pages in [fromPage]–[toPage] (1-based).
  /// Out-of-range pages get a zero-size rect so they are not scrollable.
  static PdfPageLayout layoutPagesOnly({
    required List<PdfPage> pages,
    required PdfViewerParams params,
    required int fromPage,
    required int toPage,
  }) {
    if (pages.isEmpty) {
      return PdfPageLayout(pageLayouts: const [], documentSize: Size.zero);
    }

    final lo = clampPage(fromPage, 1, pages.length);
    final hi = clampPage(toPage, 1, pages.length);
    final start = math.min(lo, hi);
    final end = math.max(lo, hi);

    final inRange = <PdfPage>[
      for (var i = start; i <= end; i++) pages[i - 1],
    ];
    final width = inRange.fold<double>(
          0,
          (w, p) => math.max(w, p.width),
        ) +
        params.margin * 2;

    final layouts = List<Rect>.filled(pages.length, Rect.zero);
    var y = params.margin;
    for (var i = start; i <= end; i++) {
      final page = pages[i - 1];
      layouts[i - 1] = Rect.fromLTWH(
        (width - page.width) / 2,
        y,
        page.width,
        page.height,
      );
      y += page.height + params.margin;
    }

    return PdfPageLayout(
      pageLayouts: layouts,
      documentSize: Size(width, y),
    );
  }
}
