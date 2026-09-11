import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:folio/core/constants/app_constants.dart';
import 'package:folio/core/errors/cancelled_exception.dart';
import 'package:folio/features/ai/data/local_gemma_service.dart';
import 'package:folio/features/ai/domain/folio_ai_provider.dart';
import 'package:folio/features/ai/domain/on_device_model.dart';
import 'package:folio/features/chat/data/api_exception.dart';
import 'package:folio/features/chat/data/network_exception.dart';
import 'package:folio/features/sessions/domain/reading_session.dart';

class FolioAiService {
  FolioAiService({
    GenerativeModel? model,
    String? apiKey,
    FolioAiProvider provider = FolioAiProvider.gemini,
    OnDeviceModel? onDeviceModel,
  })  : _provider = provider,
        _onDeviceModel = onDeviceModel ?? OnDeviceModels.defaultModel,
        _model = provider == FolioAiProvider.onDevice
            ? null
            : (model ?? _createModel(apiKey));

  final FolioAiProvider _provider;
  final OnDeviceModel _onDeviceModel;
  final GenerativeModel? _model;

  static const defaultPrompt = '''
You are Folio, a study assistant for academic and technical reading.

Summarize the source for a student who will review this later without reopening the book.

Rules:
- Prefer substance over fluff: definitions, claims, methods, results, trade-offs, and caveats.
- Preserve important technical terms; do not invent facts not present in the source.
- If the source is unclear or incomplete, say so briefly instead of guessing.
- Match the requested Output format and Length from the user message.
- Do not add a title, preamble, or closing remarks — return only the summary content.
- For Bullet format: one idea per line, no leading "- " or numbering.
''';

  bool get usesOnDevice => _provider == FolioAiProvider.onDevice;

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

  Future<String> _completeText(
    String prompt, {
    bool Function()? isCancelled,
  }) async {
    if (isCancelled?.call() ?? false) {
      throw const CancelledException('Summarization cancelled.');
    }
    if (usesOnDevice) {
      return LocalGemmaService.instance.generate(
        prompt,
        model: _onDeviceModel,
        isCancelled: isCancelled,
      );
    }
    return _awaitUnlessCancelled(
      _model!.generateContent([Content.text(prompt)]).then(
        (response) => response.text?.trim() ?? '',
      ),
      isCancelled: isCancelled,
    );
  }

  /// Completes [future] unless [isCancelled] flips first (best-effort for Gemini).
  Future<String> _awaitUnlessCancelled(
    Future<String> future, {
    bool Function()? isCancelled,
  }) async {
    if (isCancelled == null) return future;

    final done = Completer<String>();
    Timer? poll;

    void completeCancel() {
      if (!done.isCompleted) {
        done.completeError(
          const CancelledException('Summarization cancelled.'),
        );
      }
    }

    if (isCancelled()) {
      unawaited(future.catchError((_) => ''));
      throw const CancelledException('Summarization cancelled.');
    }

    future.then(
      (value) {
        if (!done.isCompleted) done.complete(value);
      },
      onError: (Object error, StackTrace stack) {
        if (!done.isCompleted) done.completeError(error, stack);
      },
    );

    poll = Timer.periodic(const Duration(milliseconds: 150), (_) {
      if (isCancelled()) {
        unawaited(future.catchError((_) => ''));
        completeCancel();
        poll?.cancel();
      }
    });

    try {
      return await done.future;
    } finally {
      poll.cancel();
    }
  }

  Future<String> _completeWithPdf({
    required String prompt,
    required Uint8List pdfBytes,
  }) async {
    if (usesOnDevice) {
      throw ApiException(
        'On-device AI cannot read PDF bytes. Use extracted text or switch to Gemini Cloud.',
      );
    }
    final response = await _model!.generateContent([
      Content.multi([
        TextPart(prompt),
        DataPart('application/pdf', pdfBytes),
      ]),
    ]);
    return response.text?.trim() ?? '';
  }

  static String topicDetectionPrompt({
    required int fromPage,
    required int toPage,
  }) {
    return '''
You are Folio's chapter detector for academic/technical PDFs.
Analyze ONLY pages $fromPage–$toPage of the attached PDF (inclusive).

TASK
Split the window into contiguous CHAPTER-level reading segments.
This is for a study app: users want whole chapters, not every subheading.

WHAT COUNTS AS A CHAPTER START
Accept a new segment only when you see a strong top-level break:
1) Explicit chapter markers: "Chapter N", "CHAPTER N", «فصل …», "Part N" (if Parts are primary)
2) Large/bold/display title on its own, usually near the top of a page, often followed by body text
3) Top-level numbering that restarts chapters: "1 …", "2 …" (NOT "1.1", "2.3.4")

IGNORE (do not start a segment)
- Subsections (1.1, 2.3, Section 3.2)
- Running headers/footers, page numbers
- Figure/table captions, equations, footnotes
- Exercises, references line-items, author affiliations
- TOC-style dotted lists ("Title …… 12") when they appear as contents pages
- Tiny bold phrases mid-paragraph

SEGMENTATION RULES
- Prefer FEWER, meaningful chapters over noisy micro-splits.
- If unsure whether something is a chapter or subsection → merge into the current chapter.
- Cover the whole window with no gaps/overlaps.
- Titles: 2–14 words, original language, keep chapter numbers when present.
- Pages before the first clear chapter: one "Front matter" (or a short descriptive title).
- If the whole window is one continuous unit → a single topic spanning $fromPage–$toPage.
- If unreadable → one low-confidence topic for the full window.

HARD RULES
- Stay inside $fromPage–$toPage.
- Contiguous: first.fromPage == $fromPage, last.toPage == $toPage,
  next.fromPage == prev.toPage + 1.
- STRICT JSON only.

OUTPUT
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
  "notes": "optional short note"
}

If the PDF pages are unreadable/empty, return:
{"window":{"fromPage":$fromPage,"toPage":$toPage},"topics":[{"title":"Untitled section","fromPage":$fromPage,"toPage":$toPage,"confidence":"low","signal":"inferred"}],"notes":"Could not read headings in this window."}
''';
  }

  /// Hybrid TOC refine: offline candidates + raw TOC text (no full PDF upload).
  static String tocRefinePrompt({
    required int fromPage,
    required int toPage,
    required String offlineCandidatesJson,
    required String rawTocText,
  }) {
    return '''
You are Folio's chapter segmenter for technical/academic books.
PDF page indices are 1-based (same as pdfrx).

INPUT
- User window: pages $fromPage–$toPage (inclusive).
- Offline TOC candidates (may be incomplete, wrong pages, glued words, missing early chapters):
$offlineCandidatesJson
  // each: { "title": string, "startPage": number }
- Raw selectable text from likely TOC pages (spaces may be missing; reconstruct titles):
"""
$rawTocText
"""

GOAL
Build a clean, contiguous chapter map for reading — ONE segment per CHAPTER (or equivalent top-level unit), not per subsection.

GRANULARITY (CRITICAL)
- Prefer CHAPTER level only:
  - English: "Chapter 1", "CHAPTER 3", "1 Introduction", "Part I" only if Parts are the main TOC units
  - Numbered top-level: "1.", "2.", "3." when those are chapters
  - Persian: «فصل ۱»، «فصل اول»، «بخش ۱»، عناوین سطح‌اول فهرست
- EXCLUDE subsections / micro-headings unless the TOC has almost no chapter-level entries:
  - "1.1", "1.2.3", "Section 2.3", "۳.۱", exercises, figures, tables, "Further reading"
- Typical good count: roughly 5–40 chapters for a full book — not 80+ fragments.
- If TOC mixes chapters and sections, KEEP chapters and DROP sections.

PAGE MAPPING
- Output pages are absolute PDF indices inside $fromPage–$toPage.
- Printed page numbers in the book may differ from PDF indices.
- Infer a single integer offset from MULTIPLE consistent anchors
  (printedPage + offset = pdfPage). Never invent offset from one entry.
- If offline candidates already form a coherent increasing PDF sequence, prefer them.
- For each chapter i: fromPage = start_i, toPage = start_{i+1} - 1; last chapter ends at $toPage.
- Starts must be strictly increasing.

FRONT MATTER
- Only include Preface / Contents / Acknowledgments / Part dividers if TOC names them.
- Pages before the first real chapter: at most ONE segment titled "Front matter"
  (or named TOC titles). Never dump early chapters into one giant "Untitled section".

TITLE CLEANUP
- Restore spaces/punctuation: "6.DecisionTrees" → "6. Decision Trees".
- Keep original language (Persian/English/…).
- Keep useful chapter numbers in the title.
- Titles: 2–14 words, non-empty. Prefer TOC wording over invented labels.
- Avoid literal "Untitled section" unless truly unknowable.

HARD CONSTRAINTS
1) Stay inside $fromPage–$toPage.
2) Contiguous coverage, no gaps/overlaps:
   first.fromPage == $fromPage
   last.toPage == $toPage
   each next.fromPage == previous.toPage + 1
3) Do not skip chapter numbers present in TOC (if TOC has 1…5 then 6, all must appear).
4) Output STRICT JSON only — no markdown, no commentary.

OUTPUT SCHEMA
{
  "window": { "fromPage": $fromPage, "toPage": $toPage },
  "topics": [
    {
      "title": "string",
      "fromPage": number,
      "toPage": number,
      "confidence": "high" | "medium" | "low",
      "signal": "toc" | "toc_inferred" | "offset_mapped"
    }
  ],
  "notes": "what you fixed: missing chapters / offset / dropped subsections / title cleanup",
  "pageOffsetUsed": null
}

SELF-CHECK BEFORE ANSWERING
- Contiguous? Chapter-level (not subsection soup)? Early chapters present?
- Starts strictly increasing? Titles cleaned? Language preserved?
''';
  }

  /// Refines incomplete offline TOC using Gemini (text-only; no PDF bytes).
  Future<TopicDetectionResult> refineToc({
    required int fromPage,
    required int toPage,
    required List<Map<String, dynamic>> offlineCandidates,
    required String rawTocText,
  }) async {
    if (fromPage < 1 || toPage < fromPage) {
      throw ApiException('Enter a valid page range.');
    }

    final candidatesJson = const JsonEncoder.withIndent('  ').convert(
      offlineCandidates,
    );
    final prompt = tocRefinePrompt(
      fromPage: fromPage,
      toPage: toPage,
      offlineCandidatesJson: candidatesJson,
      rawTocText: rawTocText.trim().isEmpty ? '(empty)' : rawTocText,
    );

    try {
      final text = await _completeText(prompt);
      if (text.isEmpty) {
        return TopicDetectionResult.fallback(fromPage, toPage);
      }

      final parsed = TopicDetectionResult.parse(
        text,
        fromPage: fromPage,
        toPage: toPage,
      );
      final notes = parsed.notes;
      return TopicDetectionResult(
        fromPage: parsed.fromPage,
        toPage: parsed.toPage,
        topics: parsed.topics,
        notes: (notes == null || notes.isEmpty)
            ? 'From TOC + AI refine'
            : 'From TOC + AI refine — $notes',
      );
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
      rethrow;
    }
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
      final text = await _completeWithPdf(prompt: prompt, pdfBytes: pdfBytes);
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

  /// Summarize plain extracted section text (lighter than uploading full PDF).
  Future<List<String>> summarizeText({
    required String text,
    required String format,
    required String length,
    String? customPrompt,
    bool Function()? isCancelled,
  }) async {
    final maxChars = usesOnDevice ? 2800 : 120000;
    final clipped = text.length > maxChars ? text.substring(0, maxChars) : text;
    final prompt = '''
${customPrompt?.trim().isNotEmpty == true ? customPrompt!.trim() : defaultPrompt}

Output format: $format
Length: $length

Return ONLY the summary lines. For Bullet format, one bullet per line without leading "- " markers.

SOURCE TEXT:
$clipped
''';

    try {
      final out = await _completeText(prompt, isCancelled: isCancelled);
      if (out.isEmpty) {
        throw ApiException(AppConstants.genericErrorMessage);
      }
      return _parseBullets(out);
    } on CancelledException {
      rethrow;
    } on SocketException {
      throw NetworkException(AppConstants.offlineErrorMessage);
    } on TimeoutException {
      throw NetworkException(AppConstants.offlineErrorMessage);
    } on GenerativeAIException catch (error) {
      throw ApiException(error.message);
    } catch (error) {
      if (error is CancelledException) rethrow;
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
    final prompt =
        'You are Folio, a reading assistant. $scopeHint\n\nQuestion: $question';

    try {
      return await _completeWithPdf(prompt: prompt, pdfBytes: pdfBytes);
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

  /// Text-grounded Q&A (preferred for on-device models that cannot ingest PDF bytes).
  Future<String> askAboutText({
    required String contextText,
    required String question,
    required String scope,
    int? fromPage,
    int? toPage,
  }) async {
    final scopeHint = scope == 'Section' && fromPage != null && toPage != null
        ? 'Answer using mainly pages $fromPage–$toPage of the source.'
        : 'You may use the full provided source.';
    final maxChars = usesOnDevice ? 2800 : 100000;
    final clipped = contextText.length > maxChars
        ? contextText.substring(0, maxChars)
        : contextText;
    final prompt = '''
You are Folio, a reading assistant. $scopeHint

SOURCE:
$clipped

Question: $question

Answer clearly and concisely. If the source does not contain enough information, say so.
''';

    try {
      return await _completeText(prompt);
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
      final text = await _completeWithPdf(
        prompt: topicDetectionPrompt(fromPage: fromPage, toPage: toPage),
        pdfBytes: pdfBytes,
      );

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
