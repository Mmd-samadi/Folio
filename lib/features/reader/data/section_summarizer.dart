import 'dart:io';

import 'package:nexus_chat/features/reader/data/folio_ai_service.dart';
import 'package:nexus_chat/features/sessions/domain/reading_session.dart';
import 'package:nexus_chat/features/sessions/presentation/cubit/sessions_cubit.dart';

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

    final bytes = await File(path).readAsBytes();
    final bullets = await FolioAiService(apiKey: apiKey).summarizePdf(
      pdfBytes: bytes,
      format: format,
      length: length,
      customPrompt: customPrompt,
      fromPage: session.fromPage,
      toPage: session.toPage,
    );
    await sessions.saveSummary(session.id, bullets);
    return bullets;
  }
}
