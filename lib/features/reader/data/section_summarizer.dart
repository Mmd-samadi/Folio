import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:nexus_chat/features/ai/domain/folio_ai_provider.dart';
import 'package:nexus_chat/features/reader/data/folio_ai_service.dart';
import 'package:nexus_chat/features/sessions/domain/reading_session.dart';
import 'package:nexus_chat/features/sessions/presentation/cubit/sessions_cubit.dart';
import 'package:pdfrx/pdfrx.dart';

Uint8List _readFileBytes(String path) => File(path).readAsBytesSync();

/// Shared summarization for Book folder cards and Reader.
class SectionSummarizer {
  const SectionSummarizer();

  Future<List<String>> summarize({
    required ReadingSession session,
    required SessionsCubit sessions,
    required String apiKey,
    required String format,
    required String length,
    String? customPrompt,
    FolioAiProvider provider = FolioAiProvider.gemini,
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

    // Let the UI paint loading state before heavy work.
    await Future<void>.delayed(Duration.zero);

    final ai = FolioAiService(apiKey: apiKey, provider: provider);

    // Prefer section text extraction (avoids uploading multi-MB PDFs).
    // Required for on-device models that cannot ingest PDF bytes.
    final sectionText = await extractSectionText(
      path,
      session.fromPage,
      session.toPage,
    );
    List<String> bullets;
    if (sectionText.trim().length >= 200 ||
        provider == FolioAiProvider.onDevice) {
      if (sectionText.trim().isEmpty) {
        throw StateError(
          'Could not extract text from this section for on-device summarization.',
        );
      }
      bullets = await ai.summarizeText(
        text: sectionText,
        format: format,
        length: length,
        customPrompt: customPrompt,
      );
    } else {
      final bytes = await compute(_readFileBytes, path);
      bullets = await ai.summarizePdf(
        pdfBytes: bytes,
        format: format,
        length: length,
        customPrompt: customPrompt,
        fromPage: session.fromPage,
        toPage: session.toPage,
      );
    }

    await sessions.saveSummary(session.id, bullets);
    return bullets;
  }

  Future<String> extractSectionText(
    String path,
    int fromPage,
    int toPage,
  ) async {
    PdfDocument? doc;
    try {
      doc = await PdfDocument.openFile(path);
      if (doc.pages.isEmpty) return '';
      final lo = fromPage.clamp(1, doc.pages.length);
      final hi = toPage.clamp(1, doc.pages.length);
      final buffer = StringBuffer();
      for (var p = lo; p <= hi; p++) {
        final page = doc.pages[p - 1];
        final text = await page.loadText();
        final full = text?.fullText.trim() ?? '';
        if (full.isEmpty) continue;
        if (buffer.isNotEmpty) buffer.writeln();
        buffer.writeln(full);
        // Yield so UI stays responsive on long sections.
        await Future<void>.delayed(Duration.zero);
      }
      return buffer.toString();
    } catch (_) {
      return '';
    } finally {
      await doc?.dispose();
    }
  }
}
