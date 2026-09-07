import 'package:nexus_chat/features/ai/domain/folio_ai_provider.dart';

class FolioSettings {
  const FolioSettings({
    this.format = 'Bullet',
    this.length = 'Medium',
    this.chatScope = 'Section',
    this.apiKey = '',
    this.customPrompt = '',
    this.summaryTextDirection = 'ltr',
    this.aiProvider = FolioAiProvider.onDevice,
  });

  final String format;
  final String length;
  final String chatScope;
  final String apiKey;
  final String customPrompt;
  /// `ltr` or `rtl` for Summary tab text.
  final String summaryTextDirection;
  final FolioAiProvider aiProvider;

  bool get hasApiKey => apiKey.trim().isNotEmpty;

  bool get usesOnDeviceAi => aiProvider == FolioAiProvider.onDevice;

  bool get summaryIsRtl => summaryTextDirection.toLowerCase() == 'rtl';

  String get maskedApiKey {
    final key = apiKey.trim();
    if (key.isEmpty) return 'Not set';
    if (key.length <= 8) return '••••••••';
    return '••••${key.substring(key.length - 4)}';
  }

  FolioSettings copyWith({
    String? format,
    String? length,
    String? chatScope,
    String? apiKey,
    String? customPrompt,
    String? summaryTextDirection,
    FolioAiProvider? aiProvider,
  }) {
    return FolioSettings(
      format: format ?? this.format,
      length: length ?? this.length,
      chatScope: chatScope ?? this.chatScope,
      apiKey: apiKey ?? this.apiKey,
      customPrompt: customPrompt ?? this.customPrompt,
      summaryTextDirection: summaryTextDirection ?? this.summaryTextDirection,
      aiProvider: aiProvider ?? this.aiProvider,
    );
  }

  Map<String, dynamic> toJson() => {
        'format': format,
        'length': length,
        'chatScope': chatScope,
        'apiKey': apiKey,
        'customPrompt': customPrompt,
        'summaryTextDirection': summaryTextDirection,
        'aiProvider': aiProvider.storageValue,
      };

  factory FolioSettings.fromJson(Map<String, dynamic> json) {
    final dir = (json['summaryTextDirection'] as String? ?? 'ltr').toLowerCase();
    return FolioSettings(
      format: json['format'] as String? ?? 'Bullet',
      length: json['length'] as String? ?? 'Medium',
      chatScope: json['chatScope'] as String? ?? 'Section',
      apiKey: json['apiKey'] as String? ?? '',
      customPrompt: json['customPrompt'] as String? ?? '',
      summaryTextDirection: dir == 'rtl' ? 'rtl' : 'ltr',
      aiProvider: FolioAiProvider.fromStorage(json['aiProvider'] as String?),
    );
  }
}
