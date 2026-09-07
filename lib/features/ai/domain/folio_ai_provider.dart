enum FolioAiProvider {
  onDevice,
  gemini;

  static const storageOnDevice = 'onDevice';
  static const storageGemini = 'gemini';

  String get storageValue =>
      this == FolioAiProvider.onDevice ? storageOnDevice : storageGemini;

  String get label =>
      this == FolioAiProvider.onDevice ? 'On-device (Gemma)' : 'Gemini Cloud';

  static FolioAiProvider fromStorage(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    if (value == storageGemini || value == 'cloud') {
      return FolioAiProvider.gemini;
    }
    return FolioAiProvider.onDevice;
  }
}
