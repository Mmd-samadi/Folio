import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_chat/features/import/data/heading_topic_detector.dart';
import 'package:nexus_chat/features/import/data/toc_refine.dart';
import 'package:nexus_chat/features/import/data/toc_section_detector.dart';
import 'package:nexus_chat/features/reader/data/folio_ai_service.dart';
import 'package:nexus_chat/features/reader/domain/section_siblings.dart';
import 'package:nexus_chat/features/reader/domain/summarize_eta.dart';
import 'package:nexus_chat/features/sessions/domain/reading_session.dart';

void main() {
  group('TocSectionDetector', () {
    const toc = TocSectionDetector();

    test('parses latin and persian page numbers', () {
      expect(toc.parseTocLine('Introduction .......... 12')?.page, 12);
      expect(toc.parseTocLine('یادگیری ماشین\t۳۴')?.page, 34);
    });

    test('builds contiguous sections from TOC lines', () {
      final lines = [
        const PdfTextLine(
          pageNumber: 3,
          text: 'Table of Contents',
          height: 14,
          top: 700,
          left: 72,
        ),
        const PdfTextLine(
          pageNumber: 3,
          text: 'Intro .......... 10',
          height: 11,
          top: 650,
          left: 72,
        ),
        const PdfTextLine(
          pageNumber: 3,
          text: 'Methods .......... 20',
          height: 11,
          top: 620,
          left: 72,
        ),
        const PdfTextLine(
          pageNumber: 3,
          text: 'Results .......... 30',
          height: 11,
          top: 590,
          left: 72,
        ),
      ];

      final result = toc.detectFromLines(lines, fromPage: 1, toPage: 40);
      expect(result, isNotNull);
      expect(result!.notes, contains('table of contents'));
      expect(result.topics.first.fromPage, 1);
      expect(result.topics.first.title, 'Front matter');
      expect(result.topics.any((t) => t.title == 'Intro'), isTrue);
      expect(result.topics.last.toPage, 40);
      for (var i = 0; i < result.topics.length - 1; i++) {
        expect(result.topics[i].toPage + 1, result.topics[i + 1].fromPage);
      }
    });

    test('returns null when fewer than 2 entries', () {
      final lines = [
        const PdfTextLine(
          pageNumber: 1,
          text: 'Only one .......... 5',
          height: 11,
          top: 600,
          left: 72,
        ),
      ];
      expect(toc.detectFromLines(lines, fromPage: 1, toPage: 10), isNull);
    });

    test('analyzeFromLines exposes candidates and raw text', () {
      final lines = [
        const PdfTextLine(
          pageNumber: 2,
          text: 'Contents',
          height: 14,
          top: 700,
          left: 72,
        ),
        const PdfTextLine(
          pageNumber: 2,
          text: '1.HelloWorld .......... 10',
          height: 11,
          top: 650,
          left: 72,
        ),
        const PdfTextLine(
          pageNumber: 2,
          text: '2.NextChapter .......... 20',
          height: 11,
          top: 620,
          left: 72,
        ),
      ];
      final analysis = toc.analyzeFromLines(lines, fromPage: 1, toPage: 30);
      expect(analysis, isNotNull);
      expect(analysis!.candidates.length, 2);
      expect(analysis.rawTocText, contains('HelloWorld'));
      expect(analysis.candidatesJson.first['startPage'], 10);
    });
  });

  group('TocRefine', () {
    test('restores glued title spaces', () {
      expect(
        TocRefine.restoreTitleSpaces('6.DecisionTrees'),
        '6. Decision Trees',
      );
    });

    test('needsRefine on large placeholder gap and chapter jump', () {
      final jumped = TopicDetectionResult(
        fromPage: 1,
        toPage: 300,
        topics: const [
          DetectedChapter(
            title: 'Front matter',
            fromPage: 1,
            toPage: 194,
          ),
          DetectedChapter(
            title: '6. Decision Trees',
            fromPage: 195,
            toPage: 300,
          ),
        ],
        notes: 'From table of contents',
      );
      expect(TocRefine.needsRefine(jumped), isTrue);

      final clean = TopicDetectionResult(
        fromPage: 1,
        toPage: 40,
        topics: const [
          DetectedChapter(title: 'Front matter', fromPage: 1, toPage: 9),
          DetectedChapter(title: '1. Intro', fromPage: 10, toPage: 19),
          DetectedChapter(title: '2. Methods', fromPage: 20, toPage: 40),
        ],
      );
      expect(TocRefine.needsRefine(clean), isFalse);
    });
  });

  group('OfflineSectionDetector facade', () {
    test('falls back to headings when TOC missing', () {
      const toc = TocSectionDetector();
      const headings = HeadingTopicDetector();
      final lines = [
        const PdfTextLine(
          pageNumber: 1,
          text: 'Introduction to Folio',
          height: 18,
          top: 700,
          left: 72,
        ),
        const PdfTextLine(
          pageNumber: 1,
          text:
              'This is a long body paragraph that explains the product in detail for readers.',
          height: 11,
          top: 650,
          left: 72,
        ),
        const PdfTextLine(
          pageNumber: 4,
          text: 'Methods',
          height: 17,
          top: 720,
          left: 72,
        ),
        const PdfTextLine(
          pageNumber: 4,
          text:
              'Another long body paragraph describing methodology and sample setup carefully.',
          height: 11,
          top: 680,
          left: 72,
        ),
      ];

      expect(toc.detectFromLines(lines, fromPage: 1, toPage: 8), isNull);
      final fallback = headings.detectFromLines(lines, fromPage: 1, toPage: 8);
      expect(fallback.notes, contains('heading'));
      expect(fallback.topics.length, greaterThanOrEqualTo(2));
    });
  });

  group('SectionSiblings', () {
    final now = DateTime(2026, 1, 1);
    final sessions = [
      ReadingSession(
        id: 'a',
        title: 'A',
        pdfName: 'x.pdf',
        fromPage: 1,
        toPage: 5,
        updatedAt: now,
        bookId: 'b1',
        localPath: '/a',
      ),
      ReadingSession(
        id: 'b',
        title: 'B',
        pdfName: 'x.pdf',
        fromPage: 6,
        toPage: 10,
        updatedAt: now,
        bookId: 'b1',
        localPath: '/a',
      ),
      ReadingSession(
        id: 'c',
        title: 'C',
        pdfName: 'y.pdf',
        fromPage: 1,
        toPage: 2,
        updatedAt: now,
        bookId: 'b2',
        localPath: '/b',
      ),
    ];

    test('orders siblings and finds next/prev', () {
      final ordered = SectionSiblings.orderedForBook(sessions, 'b1');
      expect(ordered.map((s) => s.id), ['a', 'b']);
      expect(SectionSiblings.next(ordered, 'a')?.id, 'b');
      expect(SectionSiblings.previous(ordered, 'b')?.id, 'a');
      expect(SectionSiblings.next(ordered, 'b'), isNull);
      expect(SectionSiblings.previous(ordered, 'a'), isNull);
    });
  });

  group('SummarizeEta', () {
    test('clamps and labels', () {
      final s = SummarizeEta.estimateSeconds(fromPage: 1, toPage: 1);
      expect(s, greaterThanOrEqualTo(SummarizeEta.minSeconds));
      expect(SummarizeEta.label(45), '~45s');
      expect(SummarizeEta.label(90), '~1m 30s');
    });
  });
}
