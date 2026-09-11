import 'dart:async';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:folio/core/constants/app_constants.dart';
import 'package:folio/features/ai/data/local_gemma_service.dart';
import 'package:folio/features/ai/domain/folio_ai_provider.dart';
import 'package:folio/features/chat/data/api_exception.dart';
import 'package:folio/features/chat/data/chat_history_builder.dart';
import 'package:folio/features/chat/data/network_exception.dart';
import 'package:folio/features/chat/domain/message_model.dart';

class GeminiRepository {
  GeminiRepository({
    GenerativeModel? model,
    FolioAiProvider provider = FolioAiProvider.gemini,
  })  : _provider = provider,
        _model = provider == FolioAiProvider.onDevice
            ? null
            : (model ?? _createModel());

  final FolioAiProvider _provider;
  final GenerativeModel? _model;

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

  Future<String> sendMessage({
    required List<MessageModel> history,
    required String userMessage,
  }) async {
    try {
      if (_provider == FolioAiProvider.onDevice) {
        final buffer = StringBuffer();
        for (final message in history) {
          if (message.content.trim().isEmpty) continue;
          final role =
              message.role == MessageRole.user ? 'User' : 'Assistant';
          buffer.writeln('$role: ${message.content.trim()}');
        }
        if (userMessage.trim().isNotEmpty &&
            (history.isEmpty ||
                history.last.content.trim() != userMessage.trim())) {
          buffer.writeln('User: ${userMessage.trim()}');
        }
        buffer.writeln('Assistant:');
        return await LocalGemmaService.instance.generate(buffer.toString());
      }

      final contents = buildGeminiContents(history, userMessage);
      final response = await _model!.generateContent(contents);
      return response.text?.trim() ?? '';
    } on SocketException {
      throw NetworkException(AppConstants.offlineErrorMessage);
    } on TimeoutException {
      throw NetworkException(AppConstants.offlineErrorMessage);
    } on FormatException {
      throw ApiException(AppConstants.apiErrorMessage);
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

  bool _isNetworkError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('clientexception') ||
        message.contains('connection') ||
        message.contains('network') ||
        message.contains('failed host lookup') ||
        message.contains('socket');
  }
}
