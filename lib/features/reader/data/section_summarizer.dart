import 'dart:io';
import 'dart:math' as math;

import 'package:folio/core/errors/cancelled_exception.dart';
import 'package:folio/features/ai/domain/folio_ai_provider.dart';
import 'package:folio/features/ai/domain/on_device_model.dart';
import 'package:folio/features/books/presentation/cubit/books_cubit.dart';
import 'package:folio/features/reader/data/folio_ai_service.dart';
import 'package:folio/features/reader/domain/summary_segment.dart';
import 'package:folio/features/sessions/domain/reading_session.dart';
import 'package:folio/features/sessions/presentation/cubit/sessions_cubit.dart';
import 'package:pdfrx/pdfrx.dart';

/// Shared summarization for Book folder cards and Reader.
class SectionSummarizer {
  const SectionSummarizer();

  /// Soft char budget per on-device call (keeps under ~1024-token windows).
  static const onDeviceChunkChars = 2400;

  /// Larger budget for cloud Gemini text path.
  static const cloudChunkChars = 48000;

  Future<List<String>> summarize({
    required ReadingSession session,
    required SessionsCubit sessions,
    required String apiKey,
    required String format,
    required String length,
    String? customPrompt,
    FolioAiProvider provider = FolioAiProvider.gemini,
    OnDeviceModel? onDeviceModel,
    BooksCubit? books,
    bool Function()? isCancelled,
  }) async {
    if (!session.hasLocalPdf) {
      throw StateError(
        'No PDF file found for this section. Import a PDF to continue.',
      );
    }
    final path = session.localPath!;
    if (!File(path).existsSync()) {
      throw StateError('Could not read the PDF file.');
    }

    final segment = await summarizeRange(
      pdfPath: path,
      fromPage: session.fromPage,
      toPage: session.toPage,
      apiKey: apiKey,
      format: format,
      length: length,
      customPrompt: customPrompt,
      provider: provider,
      onDeviceModel: onDeviceModel,
      existingId: null,
      isCancelled: isCancelled,
    );

    _throwIfCancelled(isCancelled);

    await sessions.saveSummary(session.id, segment.bullets);

    final bookId = session.bookId;
    if (books != null && bookId != null && bookId.isNotEmpty) {
      await books.upsertSummarySegment(bookId: bookId, segment: segment);
    }

    return segment.bullets;
  }

  /// Summarize an arbitrary page window and return a [SummarySegment].
  Future<SummarySegment> summarizeRange({
    required String pdfPath,
    required int fromPage,
    required int toPage,
    required String apiKey,
    required String format,
    required String length,
    String? customPrompt,
    FolioAiProvider provider = FolioAiProvider.gemini,
    OnDeviceModel? onDeviceModel,
    String? existingId,
    bool Function()? isCancelled,
  }) async {
    if (!File(pdfPath).existsSync()) {
      throw StateError('Could not read the PDF file.');
    }
    if (fromPage < 1 || toPage < fromPage) {
      throw StateError('Enter a valid page range.');
    }

    _throwIfCancelled(isCancelled);
    await Future<void>.delayed(Duration.zero);

    final ai = FolioAiService(
      apiKey: apiKey,
      provider: provider,
      onDeviceModel: onDeviceModel,
    );

    final text = await extractSectionText(
      pdfPath,
      fromPage,
      toPage,
      isCancelled: isCancelled,
    );
    _throwIfCancelled(isCancelled);
    if (text.trim().isEmpty) {
      throw StateError(
        'Could not extract text from pages $fromPage–$toPage.',
      );
    }

    final chunkLimit = provider == FolioAiProvider.onDevice
        ? onDeviceChunkChars
        : cloudChunkChars;
    final chunks = _splitText(text, chunkLimit);
    final allBullets = <String>[];

    for (var i = 0; i < chunks.length; i++) {
      _throwIfCancelled(isCancelled);
      final chunk = chunks[i];
      final labeled = chunks.length == 1
          ? chunk
          : 'Part ${i + 1} of ${chunks.length} (pages $fromPage–$toPage):\n$chunk';
      final bullets = await ai.summarizeText(
        text: labeled,
        format: format,
        length: length,
        customPrompt: customPrompt,
        isCancelled: isCancelled,
      );
      _throwIfCancelled(isCancelled);
      allBullets.addAll(bullets);
      await Future<void>.delayed(Duration.zero);
    }

    final now = DateTime.now();
    final id = existingId?.trim().isNotEmpty == true
        ? existingId!.trim()
        : 'sum_${now.microsecondsSinceEpoch}_${fromPage}_$toPage';

    return SummarySegment(
      id: id,
      fromPage: fromPage,
      toPage: toPage,
      bullets: allBullets,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<String> extractSectionText(
    String path,
    int fromPage,
    int toPage, {
    bool Function()? isCancelled,
  }) async {
    PdfDocument? doc;
    try {
      doc = await PdfDocument.openFile(path);
      if (doc.pages.isEmpty) return '';
      final lo = fromPage.clamp(1, doc.pages.length);
      final hi = toPage.clamp(1, doc.pages.length);
      final buffer = StringBuffer();
      for (var p = lo; p <= hi; p++) {
        _throwIfCancelled(isCancelled);
        final page = doc.pages[p - 1];
        final text = await page.loadText();
        final full = text?.fullText.trim() ?? '';
        if (full.isEmpty) continue;
        if (buffer.isNotEmpty) buffer.writeln();
        buffer.writeln(full);
        await Future<void>.delayed(Duration.zero);
      }
      return buffer.toString();
    } on CancelledException {
      rethrow;
    } catch (_) {
      return '';
    } finally {
      await doc?.dispose();
    }
  }

  static void _throwIfCancelled(bool Function()? isCancelled) {
    if (isCancelled?.call() ?? false) {
      throw const CancelledException('Summarization cancelled.');
    }
  }

  /// Splits [text] into chunks near [limit], preferring paragraph boundaries.
  static List<String> _splitText(String text, int limit) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const [];
    if (trimmed.length <= limit) return [trimmed];

    final chunks = <String>[];
    var start = 0;
    while (start < trimmed.length) {
      var end = math.min(start + limit, trimmed.length);
      if (end < trimmed.length) {
        final window = trimmed.substring(start, end);
        final breakAt = math.max(
          window.lastIndexOf('\n\n'),
          window.lastIndexOf('\n'),
        );
        if (breakAt > limit ~/ 3) {
          end = start + breakAt;
        }
      }
      final piece = trimmed.substring(start, end).trim();
      if (piece.isNotEmpty) chunks.add(piece);
      start = end;
      while (start < trimmed.length &&
          (trimmed[start] == '\n' || trimmed[start] == ' ')) {
        start++;
      }
    }
    return chunks;
  }
}
