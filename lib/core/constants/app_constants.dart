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

  static const localModelMissingMessage =
      'On-device model is not installed. Open Settings to download it.';

  /// Optional remote JSON catalog URL (override via .env or --dart-define).
  static const onDeviceModelsCatalogUrlEnv = 'ON_DEVICE_MODELS_CATALOG_URL';
  static const onDeviceModelsCatalogUrlDefine = 'ON_DEVICE_MODELS_CATALOG_URL';
  /// Leave empty to use bundled `assets/on_device_models.json` only.
  static const onDeviceModelsCatalogUrl = '';
}
