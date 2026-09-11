import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:folio/core/errors/cancelled_exception.dart';
import 'package:folio/features/ai/domain/on_device_model.dart';
import 'package:folio/features/ai/presentation/cubit/on_device_load_cubit.dart';
import 'package:folio/features/chat/data/api_exception.dart';

/// On-device LLM via flutter_gemma (selectable LiteRT / MediaPipe models).
class LocalGemmaService {
  LocalGemmaService._();

  static final LocalGemmaService instance = LocalGemmaService._();

  OnDeviceLoadCubit? _loadCubit;

  int? _downloadProgress;
  bool _installing = false;
  String? _lastError;
  String? _installingModelId;
  CancelToken? _cancelToken;
  InferenceChat? _activeChat;
  bool _generationCancelRequested = false;

  int? get downloadProgress => _downloadProgress;
  bool get isInstalling => _installing;
  String? get lastError => _lastError;
  String? get installingModelId => _installingModelId;

  /// Stops the active model download, if any.
  void cancelDownload([String reason = 'User cancelled']) {
    _cancelToken?.cancel(reason);
  }

  /// Stops the active on-device generation turn, if any.
  Future<void> cancelGeneration() async {
    _generationCancelRequested = true;
    final chat = _activeChat;
    if (chat == null) return;
    try {
      await chat.stopGeneration();
    } catch (_) {
      // Best-effort; generate() maps cancel after return.
    }
  }

  /// Wire the app-wide load cubit so downloads/inference show the resource banner.
  void attachLoadCubit(OnDeviceLoadCubit cubit) {
    _loadCubit = cubit;
  }

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

  /// Install without driving the on-device resource banner (system notification
  /// is enough; user can keep browsing the app).
  Future<void> ensureInstalledQuietly({
    OnDeviceModel? model,
    void Function(int progress)? onProgress,
  }) {
    return ensureInstalled(
      model: model,
      onProgress: onProgress,
      reportToLoadCubit: false,
    );
  }

  Future<void> ensureInstalled({
    OnDeviceModel? model,
    void Function(int progress)? onProgress,
    bool reportToLoadCubit = true,
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

    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    _installing = true;
    _installingModelId = selected.id;
    _lastError = null;
    _downloadProgress = 0;
    onProgress?.call(0);
    if (reportToLoadCubit) {
      await _loadCubit?.begin(OnDeviceLoadKind.download, downloadProgress: 0);
    }

    try {
      await FlutterGemma.installModel(
        modelType: selected.modelType,
        fileType: selected.fileType,
      )
          .fromNetwork(selected.url)
          .withCancelToken(cancelToken)
          .withProgress((progress) {
            _downloadProgress = progress;
            onProgress?.call(progress);
            if (reportToLoadCubit) {
              _loadCubit?.updateDownloadProgress(progress);
            }
          })
          .install();
      if (cancelToken.isCancelled) {
        throw const CancelledException('Download cancelled.');
      }
      _downloadProgress = 100;
      onProgress?.call(100);
      if (reportToLoadCubit) {
        _loadCubit?.updateDownloadProgress(100);
      }
    } on CancelledException {
      rethrow;
    } on DownloadCancelledException catch (error) {
      _lastError = error.message;
      throw const CancelledException('Download cancelled.');
    } catch (error) {
      if (_isCancelError(error) || cancelToken.isCancelled) {
        _lastError = 'Download cancelled.';
        throw const CancelledException('Download cancelled.');
      }
      if (error is DownloadException) {
        _lastError = error.error.toUserMessage();
        throw ApiException(_lastError!);
      }
      _lastError = error.toString();
      throw ApiException(
        'Failed to download on-device model. Check your connection and try again.',
      );
    } finally {
      _installing = false;
      _installingModelId = null;
      if (identical(_cancelToken, cancelToken)) {
        _cancelToken = null;
      }
      if (reportToLoadCubit) {
        await _loadCubit?.end();
      }
    }
  }

  static bool _isCancelError(Object error) {
    if (CancelToken.isCancel(error)) return true;
    if (error is DownloadCancelledException) return true;
    if (error is CancelledException) return true;
    final text = error.toString().toLowerCase();
    return text.contains('cancelled') || text.contains('canceled');
  }

  /// Soft cap so long PDF sections don't blow the context window / native heap.
  /// Kept tight for on-device models with ~1024-token windows.
  static const int maxPromptChars = 2800;

  Future<String> generate(
    String prompt, {
    OnDeviceModel? model,
    String? systemInstruction,
    bool Function()? isCancelled,
    // Keep the context window modest — large maxTokens + big prompts OOM-kill
    // the process on many phones (Dart catch cannot recover from that).
    int maxTokens = 1024,
    int maxOutputTokens = 512,
  }) async {
    void throwIfCancelled() {
      if (_generationCancelRequested || (isCancelled?.call() ?? false)) {
        throw const CancelledException('Summarization cancelled.');
      }
    }

    _generationCancelRequested = false;
    throwIfCancelled();
    final selected = model ?? OnDeviceModels.defaultModel;
    await ensureInstalled(model: selected);
    throwIfCancelled();

    final clipped = prompt.length > maxPromptChars
        ? prompt.substring(0, maxPromptChars)
        : prompt;

    await _loadCubit?.begin(OnDeviceLoadKind.infer);

    // CPU-only: GPU/OpenCL often SIGSEGV or OOM-kills the process before any
    // Dart fallback to CPU can run (LiteRT-LM OpenCL issues on Mali/Adreno).
    InferenceModel? inference;
    InferenceChat? chat;
    try {
      throwIfCancelled();
      inference = await FlutterGemma.getActiveModel(
        maxTokens: maxTokens,
        preferredBackend: PreferredBackend.cpu,
      );
      throwIfCancelled();
      chat = await inference.createChat(
        systemInstruction: systemInstruction ??
            'You are Folio, a concise reading assistant for academic PDFs.',
        maxOutputTokens: maxOutputTokens,
      );
      _activeChat = chat;
      throwIfCancelled();
      await chat.addQueryChunk(
        Message.text(text: clipped, isUser: true),
      );
      throwIfCancelled();
      final response = await chat.generateChatResponse();
      throwIfCancelled();
      final text = _responseText(response);
      if (text.isEmpty &&
          (_generationCancelRequested || (isCancelled?.call() ?? false))) {
        throw const CancelledException('Summarization cancelled.');
      }
      return text;
    } on CancelledException {
      rethrow;
    } catch (error) {
      if (_generationCancelRequested || (isCancelled?.call() ?? false)) {
        throw const CancelledException('Summarization cancelled.');
      }
      if (_isCancelError(error)) {
        throw const CancelledException('Summarization cancelled.');
      }
      if (error is ApiException) rethrow;
      throw ApiException(
        error.toString().trim().isEmpty
            ? 'On-device model failed to generate a response.'
            : error.toString(),
      );
    } finally {
      if (identical(_activeChat, chat)) {
        _activeChat = null;
      }
      _generationCancelRequested = false;
      await inference?.close();
      await _loadCubit?.end();
    }
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
