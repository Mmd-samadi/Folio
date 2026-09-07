import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:nexus_chat/core/constants/app_constants.dart';
import 'package:nexus_chat/features/chat/data/api_exception.dart';
import 'package:nexus_chat/features/chat/data/network_exception.dart';
import 'package:nexus_chat/features/sessions/domain/reading_session.dart';

class FolioAiService {
  FolioAiService({GenerativeModel? model, String? apiKey})
      : _model = model ?? _createModel(apiKey);

  final GenerativeModel _model;

  static const defaultPrompt =
      'Summarize the following text in bullet points. Focus on key concepts, '
      'important definitions, and actionable insights. Keep each bullet concise '
      'but informative.';

  static GenerativeModel _createModel([String? overrideKey]) {
    final fromSettings = overrideKey?.trim() ?? '';
    final fromEnv = dotenv.env[AppConstants.apiKeyEnv]?.trim() ?? '';
    final apiKey = fromSettings.isNotEmpty ? fromSettings : fromEnv;

    if (apiKey.isEmpty || apiKey == 'your_key_here') {
      throw StateError(
        'GEMINI_API_KEY is missing. Add it in Settings or your .env file.',
      );
    }

    return GenerativeModel(
      model: AppConstants.geminiModel,
      apiKey: apiKey,
    );
  }

  static String topicDetectionPrompt({
    required int fromPage,
    required int toPage,
  }) {
    return '''
You are Folio's chapter/topic detector for academic and technical PDFs.

TASK
Analyze ONLY pages $fromPage–$toPage of the attached PDF (inclusive).
Detect section topics / headings and divide this window into contiguous reading segments.
This window was chosen by the user to exclude front matter/TOC when possible.
Prefer body-section headings over table-of-contents style lists.

HOW TO DETECT TOPICS
Prefer visual hierarchy over body text:
1. Large / bold / display-style headings
2. Numbered sections (e.g. "3.1 …", "Chapter 2 …")
3. All-caps or clearly separated title lines that introduce a new section
Ignore: captions, running headers/footers, page numbers, footnotes, figure labels, table titles, author affiliations, references line items, and normal paragraph text.

WINDOW RULES (HARD)
- You MUST stay inside pages $fromPage–$toPage.
- Do not invent pages outside this window.

SEGMENTATION RULES
- Produce ordered topics that cover the window without gaps or overlaps.
- Each topic has: title, fromPage, toPage.
- Titles: concise (3–12 words), preserve original language of the heading when possible; clean numbering noise lightly (keep "3.1 Attention" style if useful).
- If a heading starts mid-window, that topic starts on that page.
- If no clear heading appears for some pages, create one topic titled "Untitled section" (or a short descriptive title from content) covering those pages — do not leave gaps.
- If the whole window is one continuous section, return a single topic spanning $fromPage–$toPage.
- Prefer fewer, meaningful topics over noisy micro-headings. Merge tiny headings that are clearly part of the same section.

OUTPUT (STRICT JSON ONLY — no markdown, no prose)
{
  "window": { "fromPage": $fromPage, "toPage": $toPage },
  "topics": [
    {
      "title": "string",
      "fromPage": number,
      "toPage": number,
      "confidence": "high" | "medium" | "low",
      "signal": "heading" | "numbered" | "inferred"
    }
  ],
  "notes": "optional short note if TOC was missing or uncertain"
}

VALIDATION BEFORE YOU ANSWER
- topics sorted by fromPage ascending
- for every topic: $fromPage ≤ fromPage ≤ toPage ≤ $toPage
- topics are contiguous: first.fromPage == $fromPage, last.toPage == $toPage, and each next.fromPage == previous.toPage + 1
- no empty titles

If the PDF pages are unreadable/empty, return:
{"window":{"fromPage":$fromPage,"toPage":$toPage},"topics":[{"title":"Untitled section","fromPage":$fromPage,"toPage":$toPage,"confidence":"low","signal":"inferred"}],"notes":"Could not read headings in this window."}
''';
  }

  Future<List<String>> summarizePdf({
    required Uint8List pdfBytes,
    required String format,
    required String length,
    String? customPrompt,
    int? fromPage,
    int? toPage,
  }) async {
    final rangeHint = (fromPage != null && toPage != null)
        ? ' Focus on pages $fromPage–$toPage when possible.'
        : '';
    final prompt = '''
${customPrompt?.trim().isNotEmpty == true ? customPrompt!.trim() : defaultPrompt}

Output format: $format
Length: $length
$rangeHint

Return ONLY the summary lines. For Bullet format, one bullet per line without leading "- " markers.
''';

    try {
      final response = await _model.generateContent([
        Content.multi([
          TextPart(prompt),
          DataPart('application/pdf', pdfBytes),
        ]),
      ]);

      final text = response.text?.trim() ?? '';
      if (text.isEmpty) {
        throw ApiException(AppConstants.genericErrorMessage);
      }
      return _parseBullets(text);
    } on SocketException {
      throw NetworkException(AppConstants.offlineErrorMessage);
    } on TimeoutException {
      throw NetworkException(AppConstants.offlineErrorMessage);
    } on GenerativeAIException catch (error) {
      throw ApiException(error.message);
    } catch (error) {
      if (_isNetworkError(error)) {
        throw NetworkException(AppConstants.offlineErrorMessage);
      }
      if (error is ApiException || error is NetworkException) rethrow;
      throw ApiException(AppConstants.genericErrorMessage);
    }
  }

  Future<String> askAboutPdf({
    required Uint8List pdfBytes,
    required String question,
    required String scope,
    int? fromPage,
    int? toPage,
  }) async {
    final scopeHint = scope == 'Section' && fromPage != null && toPage != null
        ? 'Answer using mainly pages $fromPage–$toPage.'
        : 'You may use the full PDF.';

    try {
      final response = await _model.generateContent([
        Content.multi([
          TextPart(
            'You are Folio, a reading assistant. $scopeHint\n\nQuestion: $question',
          ),
          DataPart('application/pdf', pdfBytes),
        ]),
      ]);
      return response.text?.trim() ?? '';
    } on SocketException {
      throw NetworkException(AppConstants.offlineErrorMessage);
    } on TimeoutException {
      throw NetworkException(AppConstants.offlineErrorMessage);
    } on GenerativeAIException catch (error) {
      throw ApiException(error.message);
    } catch (error) {
      if (_isNetworkError(error)) {
        throw NetworkException(AppConstants.offlineErrorMessage);
      }
      throw ApiException(AppConstants.genericErrorMessage);
    }
  }

  /// Detects topics/headings inside a page window of a PDF (legacy Gemini path).
  Future<TopicDetectionResult> detectTopics({
    required Uint8List pdfBytes,
    required int fromPage,
    required int toPage,
  }) async {
    if (fromPage < 1 || toPage < fromPage) {
      throw ApiException('Enter a valid page range.');
    }

    try {
      final response = await _model.generateContent([
        Content.multi([
          TextPart(topicDetectionPrompt(fromPage: fromPage, toPage: toPage)),
          DataPart('application/pdf', pdfBytes),
        ]),
      ]);

      final text = response.text?.trim() ?? '';
      if (text.isEmpty) {
        return TopicDetectionResult.fallback(fromPage, toPage);
      }

      return TopicDetectionResult.parse(
        text,
        fromPage: fromPage,
        toPage: toPage,
      );
    } on SocketException {
      throw NetworkException(AppConstants.offlineErrorMessage);
    } on TimeoutException {
      throw NetworkException(AppConstants.offlineErrorMessage);
    } on GenerativeAIException catch (error) {
      throw ApiException(error.message);
    } on FormatException {
      return TopicDetectionResult.fallback(
        fromPage,
        toPage,
        notes: 'Could not parse topic detection response.',
      );
    } catch (error) {
      if (_isNetworkError(error)) {
        throw NetworkException(AppConstants.offlineErrorMessage);
      }
      if (error is ApiException || error is NetworkException) rethrow;
      return TopicDetectionResult.fallback(
        fromPage,
        toPage,
        notes: 'Topic detection failed; using a single section.',
      );
    }
  }

  List<String> _parseBullets(String text) {
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .map((l) {
          return l
              .replaceFirst(RegExp(r'^[-•*]\s*'), '')
              .replaceFirst(RegExp(r'^\d+[.)]\s*'), '')
              .trim();
        })
        .where((l) => l.isNotEmpty)
        .toList();
    return lines.isEmpty ? [text] : lines;
  }

  bool _isNetworkError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('clientexception') ||
        message.contains('connection') ||
        message.contains('network') ||
        message.contains('failed host lookup') ||
        message.contains('socket');
  }
}

class TopicDetectionResult {
  const TopicDetectionResult({
    required this.fromPage,
    required this.toPage,
    required this.topics,
    this.notes,
  });

  final int fromPage;
  final int toPage;
  final List<DetectedChapter> topics;
  final String? notes;

  factory TopicDetectionResult.fallback(
    int fromPage,
    int toPage, {
    String? notes,
  }) {
    return TopicDetectionResult(
      fromPage: fromPage,
      toPage: toPage,
      topics: [
        DetectedChapter(
          title: 'Untitled section',
          fromPage: fromPage,
          toPage: toPage,
        ),
      ],
      notes: notes ?? 'Could not read headings in this window.',
    );
  }

  factory TopicDetectionResult.parse(
    String raw, {
    required int fromPage,
    required int toPage,
  }) {
    try {
      final jsonText = _extractJsonObject(raw);
      final decoded = jsonDecode(jsonText);
      if (decoded is! Map) {
        return TopicDetectionResult.fallback(fromPage, toPage);
      }

      final map = Map<String, dynamic>.from(decoded);
      final topicsRaw = map['topics'];
      final parsed = <DetectedChapter>[];

      if (topicsRaw is List) {
        for (final item in topicsRaw) {
          if (item is! Map) continue;
          final topic = Map<String, dynamic>.from(item);
          final title = (topic['title'] as String?)?.trim() ?? '';
          final start = _asInt(topic['fromPage']);
          final end = _asInt(topic['toPage']);
          if (title.isEmpty || start == null || end == null) continue;
          if (end < start) continue;
          parsed.add(
            DetectedChapter(
              title: title,
              fromPage: start.clamp(fromPage, toPage),
              toPage: end.clamp(fromPage, toPage),
            ),
          );
        }
      }

      final normalized = normalizeContiguous(parsed, fromPage, toPage);
      final notes = (map['notes'] as String?)?.trim();

      return TopicDetectionResult(
        fromPage: fromPage,
        toPage: toPage,
        topics: normalized,
        notes: notes == null || notes.isEmpty ? null : notes,
      );
    } catch (_) {
      return TopicDetectionResult.fallback(fromPage, toPage);
    }
  }

  /// Ensures topics cover [fromPage]–[toPage] without gaps or overlaps.
  static List<DetectedChapter> normalizeContiguous(
    List<DetectedChapter> input,
    int fromPage,
    int toPage,
  ) {
    if (input.isEmpty) {
      return [
        DetectedChapter(
          title: 'Untitled section',
          fromPage: fromPage,
          toPage: toPage,
        ),
      ];
    }

    final sorted = [...input]
      ..sort((a, b) => a.fromPage.compareTo(b.fromPage));

    final result = <DetectedChapter>[];
    var cursor = fromPage;

    for (final topic in sorted) {
      var start = topic.fromPage;
      var end = topic.toPage;
      if (end < cursor) continue;
      if (start < cursor) start = cursor;
      if (start > cursor) {
        result.add(
          DetectedChapter(
            title: 'Untitled section',
            fromPage: cursor,
            toPage: start - 1,
          ),
        );
      }
      if (end > toPage) end = toPage;
      if (start > end) continue;
      result.add(
        DetectedChapter(
          title: topic.title,
          fromPage: start,
          toPage: end,
        ),
      );
      cursor = end + 1;
      if (cursor > toPage) break;
    }

    if (cursor <= toPage) {
      result.add(
        DetectedChapter(
          title: 'Untitled section',
          fromPage: cursor,
          toPage: toPage,
        ),
      );
    }

    return result;
  }

  static String _extractJsonObject(String raw) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      text = text.replaceFirst(
        RegExp(r'^```(?:json)?\s*', caseSensitive: false),
        '',
      );
      text = text.replaceFirst(RegExp(r'\s*```$'), '');
      text = text.trim();
    }
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) {
      throw const FormatException('No JSON object found');
    }
    return text.substring(start, end + 1);
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }
}
