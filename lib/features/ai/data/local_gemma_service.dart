import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:nexus_chat/core/constants/app_constants.dart';
import 'package:nexus_chat/features/chat/data/api_exception.dart';

/// On-device LLM via flutter_gemma (Qwen3 0.6B LiteRT by default).
class LocalGemmaService {
  LocalGemmaService._();

  static final LocalGemmaService instance = LocalGemmaService._();

  int? _downloadProgress;
  bool _installing = false;
  String? _lastError;

  int? get downloadProgress => _downloadProgress;
  bool get isInstalling => _installing;
  String? get lastError => _lastError;

  Future<bool> isInstalled() {
    return FlutterGemma.isModelInstalled(AppConstants.localModelFileName);
  }

  Future<void> ensureInstalled({
    void Function(int progress)? onProgress,
  }) async {
    if (await isInstalled()) {
      _downloadProgress = 100;
      return;
    }
    if (_installing) {
      throw ApiException('Model download already in progress.');
    }

    _installing = true;
    _lastError = null;
    _downloadProgress = 0;
    onProgress?.call(0);

    try {
      await FlutterGemma.installModel(
        modelType: AppConstants.localModelType,
        fileType: AppConstants.localModelFileType,
      )
          .fromNetwork(AppConstants.localModelUrl)
          .withProgress((progress) {
            _downloadProgress = progress;
            onProgress?.call(progress);
          })
          .install();
      _downloadProgress = 100;
      onProgress?.call(100);
    } on DownloadException catch (error) {
      _lastError = error.error.toUserMessage();
      throw ApiException(_lastError!);
    } catch (error) {
      _lastError = error.toString();
      throw ApiException(
        'Failed to download on-device model. Check your connection and try again.',
      );
    } finally {
      _installing = false;
    }
  }

  Future<String> generate(
    String prompt, {
    String? systemInstruction,
    int maxTokens = 2048,
    int maxOutputTokens = 1024,
  }) async {
    await ensureInstalled();

    final backends = <PreferredBackend>[
      PreferredBackend.gpu,
      PreferredBackend.cpu,
    ];

    Object? lastError;
    for (final backend in backends) {
      InferenceModel? model;
      try {
        model = await FlutterGemma.getActiveModel(
          maxTokens: maxTokens,
          preferredBackend: backend,
        );
        final chat = await model.createChat(
          systemInstruction: systemInstruction ??
              'You are Folio, a concise reading assistant for academic PDFs.',
          maxOutputTokens: maxOutputTokens,
        );
        await chat.addQueryChunk(
          Message.text(text: prompt, isUser: true),
        );
        final response = await chat.generateChatResponse();
        return _responseText(response);
      } catch (error) {
        lastError = error;
      } finally {
        await model?.close();
      }
    }

    throw ApiException(
      lastError?.toString() ??
          'On-device model failed to generate a response.',
    );
  }

  String _responseText(ModelResponse response) {
    if (response is TextResponse) {
      return response.token.trim();
    }
    if (response is ThinkingResponse) {
      return response.content.trim();
    }
    return response.toString().trim();
  }
}
