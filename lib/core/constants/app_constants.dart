import 'package:flutter_gemma/flutter_gemma.dart';

class AppConstants {
  AppConstants._();

  static const geminiModel = 'gemini-2.5-flash';
  static const apiKeyEnv = 'GEMINI_API_KEY';
  static const appTitle = 'Folio';
  static const tagline = 'Read smarter';
  static const offlineErrorMessage =
      'No internet connection. Please check your network and try again.';
  static const apiErrorMessage =
      'Unable to reach Gemini. Check your connection or API key.';
  static const genericErrorMessage = 'Something went wrong. Please try again.';
  static const appVersion = 'v1.0.0';

  /// Lightweight public on-device model (~330MB). No HuggingFace auth required.
  static const localModelLabel = 'Qwen3 0.6B (on-device)';
  static const localModelFileName =
      'Qwen3-0.6B_dynamic_wi4b32_afp32.litertlm';
  static const localModelUrl =
      'https://huggingface.co/litert-community/Qwen3-0.6B/resolve/main/'
      'Qwen3-0.6B_dynamic_wi4b32_afp32.litertlm';
  static const localModelType = ModelType.qwen3;
  static const localModelFileType = ModelFileType.litertlm;
  static const localModelMissingMessage =
      'On-device model is not installed. Open Settings to download it.';
}
