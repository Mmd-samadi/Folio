class FolioSettings {
  const FolioSettings({
    this.format = 'Bullet',
    this.length = 'Medium',
    this.chatScope = 'Section',
    this.apiKey = '',
    this.customPrompt = '',
    this.summaryTextDirection = 'ltr',
  });

  final String format;
  final String length;
  final String chatScope;
  final String apiKey;
  final String customPrompt;
  /// `ltr` or `rtl` for Summary tab text.
  final String summaryTextDirection;

  bool get hasApiKey => apiKey.trim().isNotEmpty;

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
  }) {
    return FolioSettings(
      format: format ?? this.format,
      length: length ?? this.length,
      chatScope: chatScope ?? this.chatScope,
      apiKey: apiKey ?? this.apiKey,
      customPrompt: customPrompt ?? this.customPrompt,
      summaryTextDirection: summaryTextDirection ?? this.summaryTextDirection,
    );
  }

  Map<String, dynamic> toJson() => {
        'format': format,
        'length': length,
        'chatScope': chatScope,
        'apiKey': apiKey,
        'customPrompt': customPrompt,
        'summaryTextDirection': summaryTextDirection,
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
    );
  }
}
