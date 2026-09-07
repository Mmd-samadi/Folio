import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_chat/features/import/data/heading_topic_detector.dart';
import 'package:nexus_chat/features/reader/data/folio_ai_service.dart';

void main() {
  group('HeadingTopicDetector.detectFromLines', () {
    const detector = HeadingTopicDetector();

    test('larger lines become headings with contiguous page spans', () {
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
          pageNumber: 3,
          text: 'Methods',
          height: 17,
          top: 720,
          left: 72,
        ),
        const PdfTextLine(
          pageNumber: 3,
          text:
              'Another long body paragraph describing methodology and sample setup carefully.',
          height: 11,
          top: 680,
          left: 72,
        ),
        const PdfTextLine(
          pageNumber: 6,
          text: 'Results and Discussion',
          height: 17.5,
          top: 710,
          left: 72,
        ),
        const PdfTextLine(
          pageNumber: 6,
          text:
              'Body text continues here with enough characters to estimate the body font size.',
          height: 11,
          top: 660,
          left: 72,
        ),
      ];

      final result = detector.detectFromLines(
        lines,
        fromPage: 1,
        toPage: 8,
      );

      expect(result.topics.length, greaterThanOrEqualTo(3));
      expect(result.topics.map((t) => t.title), contains('Introduction to Folio'));
      expect(result.topics.map((t) => t.title), contains('Methods'));
      expect(
        result.topics.map((t) => t.title),
        contains('Results and Discussion'),
      );

      expect(result.topics.first.fromPage, 1);
      expect(result.topics.last.toPage, 8);

      // Contiguous coverage
      for (var i = 0; i < result.topics.length - 1; i++) {
        expect(
          result.topics[i].toPage + 1,
          result.topics[i + 1].fromPage,
        );
      }
    });

    test('no headings yields single fallback section', () {
      final lines = [
        const PdfTextLine(
          pageNumber: 2,
          text:
              'Only body text on this page with a consistent size and lots of words here.',
          height: 12,
          top: 600,
          left: 72,
        ),
        const PdfTextLine(
          pageNumber: 3,
          text:
              'More body text that is equally tall so nothing looks like a heading line.',
          height: 12,
          top: 580,
          left: 72,
        ),
      ];

      final result = detector.detectFromLines(
        lines,
        fromPage: 2,
        toPage: 5,
      );

      expect(result.topics, hasLength(1));
      expect(result.topics.single.fromPage, 2);
      expect(result.topics.single.toPage, 5);
      expect(result.notes, contains('No larger headings'));
    });

    test('filters page-number style lines', () {
      final lines = [
        const PdfTextLine(
          pageNumber: 1,
          text: '12',
          height: 20,
          top: 40,
          left: 300,
        ),
        const PdfTextLine(
          pageNumber: 1,
          text:
              'Body paragraph with enough characters so median body size is this height value.',
          height: 11,
          top: 500,
          left: 72,
        ),
        const PdfTextLine(
          pageNumber: 1,
          text: 'Real Heading Here',
          height: 16,
          top: 700,
          left: 72,
        ),
      ];

      final result = detector.detectFromLines(
        lines,
        fromPage: 1,
        toPage: 2,
      );

      expect(result.topics.any((t) => t.title == '12'), isFalse);
      expect(result.topics.any((t) => t.title == 'Real Heading Here'), isTrue);
    });
  });

  group('TopicDetectionResult.parse', () {
    test('parses topics and fills gaps to stay contiguous', () {
      const raw = '''
{
  "window": { "fromPage": 1, "toPage": 10 },
  "topics": [
    { "title": "Intro", "fromPage": 1, "toPage": 3, "confidence": "high", "signal": "heading" },
    { "title": "Methods", "fromPage": 5, "toPage": 8, "confidence": "medium", "signal": "numbered" }
  ],
  "notes": "gap filled"
}
''';

      final result = TopicDetectionResult.parse(raw, fromPage: 1, toPage: 10);

      expect(result.topics.first.fromPage, 1);
      expect(result.topics.last.toPage, 10);
      expect(result.topics.any((t) => t.title == 'Untitled section'), isTrue);
      expect(result.notes, 'gap filled');
    });

    test('falls back when JSON is invalid', () {
      final result = TopicDetectionResult.parse(
        'not json',
        fromPage: 2,
        toPage: 5,
      );
      expect(result.topics, hasLength(1));
      expect(result.topics.single.fromPage, 2);
      expect(result.topics.single.toPage, 5);
    });
  });
}
