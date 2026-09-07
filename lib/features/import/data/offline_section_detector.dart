import 'package:nexus_chat/features/import/data/heading_topic_detector.dart';
import 'package:nexus_chat/features/import/data/toc_refine.dart';
import 'package:nexus_chat/features/import/data/toc_section_detector.dart';
import 'package:nexus_chat/features/reader/data/folio_ai_service.dart';

/// TOC-first offline section builder; AI-refines incomplete TOC when possible.
class OfflineSectionDetector {
  const OfflineSectionDetector({
    this.headings = const HeadingTopicDetector(),
    this.toc = const TocSectionDetector(),
  });

  final HeadingTopicDetector headings;
  final TocSectionDetector toc;

  /// [resolveApiKey] is called only when offline TOC looks incomplete and
  /// AI refine would help. Return null/empty to keep the offline result.
  Future<TopicDetectionResult> detect({
    required String pdfPath,
    required int fromPage,
    required int toPage,
    void Function(String status)? onStatus,
    Future<String?> Function()? resolveApiKey,
  }) async {
    onStatus?.call('Scanning for table of contents…');
    final lines = await headings.loadLines(
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

    final lastPage = lines.map((l) => l.pageNumber).reduce(
          (a, b) => a > b ? a : b,
        );
    final clampedTo = lastPage < toPage ? lastPage : toPage;

    onStatus?.call('Building sections…');
    final analysis = toc.analyzeFromLines(
      lines,
      fromPage: fromPage,
      toPage: clampedTo,
    );

    if (analysis != null) {
      final offline = analysis.sections;
      if (!TocRefine.needsRefine(offline)) {
        return offline;
      }

      onStatus?.call('Refining table of contents…');
      final apiKey = resolveApiKey == null ? null : await resolveApiKey();
      if (apiKey != null && apiKey.trim().isNotEmpty) {
        try {
          return await FolioAiService(apiKey: apiKey).refineToc(
            fromPage: fromPage,
            toPage: clampedTo,
            offlineCandidates: analysis.candidatesJson,
            rawTocText: analysis.rawTocText,
          );
        } catch (_) {
          // Keep polished offline TOC if refine fails.
          return offline;
        }
      }
      return offline;
    }

    return headings.detectFromLines(
      lines,
      fromPage: fromPage,
      toPage: clampedTo,
    );
  }
}
