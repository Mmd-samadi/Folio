import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:nexus_chat/core/constants/app_constants.dart';
import 'package:nexus_chat/features/ai/data/local_gemma_service.dart';
import 'package:nexus_chat/features/ai/domain/folio_ai_provider.dart';
import 'package:nexus_chat/features/ai/domain/on_device_model.dart';
import 'package:nexus_chat/features/chat/data/api_exception.dart';
import 'package:nexus_chat/features/chat/data/network_exception.dart';
import 'package:nexus_chat/features/sessions/domain/reading_session.dart';

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

  Future<String> _completeText(String prompt) async {
    if (usesOnDevice) {
      return LocalGemmaService.instance.generate(
        prompt,
        model: _onDeviceModel,
      );
    }
    final response = await _model!.generateContent([Content.text(prompt)]);
    return response.text?.trim() ?? '';
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

  /// Hybrid TOC refine: offline candidates + raw TOC text (no full PDF upload).
  static String tocRefinePrompt({
    required int fromPage,
    required int toPage,
    required String offlineCandidatesJson,
    required String rawTocText,
  }) {
    return '''
You are Folio's TOC refinement engine for technical books (PDF page indices = pdfrx 1-based).

CONTEXT
- User window: pages $fromPage–$toPage (inclusive).
- Offline parser already extracted candidate TOC entries (may be incomplete, wrong page mapping, or missing early chapters).
- Below is the raw selectable text from likely TOC pages (may lack spaces between words; reconstruct readable titles).
- Printed page numbers in the book may DIFFER from PDF page indices. Prefer consistency with the offline candidates' page numbers when they form a coherent increasing sequence; if printed≠PDF, map using the observed offset inferred from multiple anchors (do not invent an offset from a single entry).

OFFLINE CANDIDATES (JSON)
$offlineCandidatesJson
// each: { "title": string, "startPage": number }

RAW TOC TEXT
"""
$rawTocText
"""

TASK
1) Reconstruct the full ordered chapter/section list that the Table of Contents intends for this window.
2) Fix missing early chapters (never collapse a large front+early-body range into a single "Untitled section" if TOC lists named chapters there).
3) Restore spaces/punctuation in titles (e.g. "6.DecisionTrees" → "6. Decision Trees"). Keep original language.
4) Assign absolute PDF start pages. Each section i: fromPage = start_i, toPage = start_{i+1}-1; last ends at $toPage.
5) Include front matter only if TOC names it (Preface, Contents, Part I, …). If TOC does not name pages before the first chapter, you MAY use ONE short title such as "Front matter" (not "Untitled section") for that prefix — or split into named front-matter items when TOC lists them.
6) Prefer chapter-level TOC entries over noisy subsection micro-entries unless the TOC clearly uses subsections as primary navigation.
7) Do not skip chapter numbers when they appear in TOC (if TOC has 1…5 then 6, all must appear).

HARD RULES
- Stay inside $fromPage–$toPage.
- Contiguous coverage: first.fromPage == $fromPage, last.toPage == $toPage, next.fromPage == prev.toPage+1.
- No empty titles. Avoid the literal title "Untitled section" unless the TOC truly has no label and content is unreadable.
- Output STRICT JSON only (no markdown).

OUTPUT
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
  "notes": "short note: what was fixed (missing chapters, page offset, title cleanup)",
  "pageOffsetUsed": null
}
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
  }) async {
    final clipped = text.length > 120000 ? text.substring(0, 120000) : text;
    final prompt = '''
${customPrompt?.trim().isNotEmpty == true ? customPrompt!.trim() : defaultPrompt}

Output format: $format
Length: $length

Return ONLY the summary lines. For Bullet format, one bullet per line without leading "- " markers.

SOURCE TEXT:
$clipped
''';

    try {
      final out = await _completeText(prompt);
      if (out.isEmpty) {
        throw ApiException(AppConstants.genericErrorMessage);
      }
      return _parseBullets(out);
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
    final clipped = contextText.length > 100000
        ? contextText.substring(0, 100000)
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
