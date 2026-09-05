import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:nexus_chat/core/constants/app_constants.dart';
import 'package:nexus_chat/features/chat/data/api_exception.dart';
import 'package:nexus_chat/features/chat/data/network_exception.dart';

class FolioAiService {
  FolioAiService({GenerativeModel? model}) : _model = model ?? _createModel();

  final GenerativeModel _model;

  static const defaultPrompt =
      'Summarize the following text in bullet points. Focus on key concepts, '
      'important definitions, and actionable insights. Keep each bullet concise '
      'but informative.';

  static GenerativeModel _createModel() {
    final apiKey = dotenv.env[AppConstants.apiKeyEnv];
    if (apiKey == null || apiKey.isEmpty || apiKey == 'your_key_here') {
      throw StateError(
        'GEMINI_API_KEY is missing. Add it to your .env file.',
      );
    }

    return GenerativeModel(
      model: AppConstants.geminiModel,
      apiKey: apiKey,
    );
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
