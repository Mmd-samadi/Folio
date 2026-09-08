import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:nexus_chat/features/ai/domain/on_device_model.dart';
import 'package:nexus_chat/features/chat/data/api_exception.dart';

/// On-device LLM via flutter_gemma (selectable LiteRT / MediaPipe models).
class LocalGemmaService {
  LocalGemmaService._();

  static final LocalGemmaService instance = LocalGemmaService._();

  int? _downloadProgress;
  bool _installing = false;
  String? _lastError;
  String? _installingModelId;

  int? get downloadProgress => _downloadProgress;
  bool get isInstalling => _installing;
  String? get lastError => _lastError;
  String? get installingModelId => _installingModelId;

  Future<bool> isInstalled([OnDeviceModel? model]) {
    final selected = model ?? OnDeviceModels.defaultModel;
    return FlutterGemma.isModelInstalled(selected.fileName);
  }

  Future<Map<String, bool>> installedStatusMap() async {
    final result = <String, bool>{};
    for (final model in OnDeviceModels.catalog) {
      result[model.id] = await FlutterGemma.isModelInstalled(model.fileName);
    }
    return result;
  }

  Future<void> ensureInstalled({
    OnDeviceModel? model,
    void Function(int progress)? onProgress,
  }) async {
    final selected = model ?? OnDeviceModels.defaultModel;
    if (await isInstalled(selected)) {
      // Re-run install to set this file as the active inference model
      // without re-downloading (flutter_gemma skips when already present).
      await FlutterGemma.installModel(
        modelType: selected.modelType,
        fileType: selected.fileType,
      ).fromNetwork(selected.url).install();
      _downloadProgress = 100;
      return;
    }
    if (_installing) {
      throw ApiException('Model download already in progress.');
    }

    _installing = true;
    _installingModelId = selected.id;
    _lastError = null;
    _downloadProgress = 0;
    onProgress?.call(0);

    try {
      await FlutterGemma.installModel(
        modelType: selected.modelType,
        fileType: selected.fileType,
      )
          .fromNetwork(selected.url)
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
      _installingModelId = null;
    }
  }

  Future<String> generate(
    String prompt, {
    OnDeviceModel? model,
    String? systemInstruction,
    int maxTokens = 2048,
    int maxOutputTokens = 1024,
  }) async {
    final selected = model ?? OnDeviceModels.defaultModel;
    await ensureInstalled(model: selected);

    final backends = <PreferredBackend>[
      PreferredBackend.gpu,
      PreferredBackend.cpu,
    ];

    Object? lastError;
    for (final backend in backends) {
      InferenceModel? inference;
      try {
        inference = await FlutterGemma.getActiveModel(
          maxTokens: maxTokens,
          preferredBackend: backend,
        );
        final chat = await inference.createChat(
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
        await inference?.close();
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
