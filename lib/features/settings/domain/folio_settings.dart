import 'package:flutter/material.dart';
import 'package:folio/core/theme/theme_cubit.dart';
import 'package:folio/features/ai/domain/folio_ai_provider.dart';
import 'package:folio/features/ai/domain/on_device_model.dart';

class FolioSettings {
  const FolioSettings({
    this.format = 'Bullet',
    this.length = 'Medium',
    this.chatScope = 'Section',
    this.apiKey = '',
    this.customPrompt = '',
    this.summaryTextDirection = 'ltr',
    this.aiProvider = FolioAiProvider.onDevice,
    this.onDeviceModelId = OnDeviceModels.fallbackDefaultId,
    this.themeMode = ThemeMode.dark,
  });

  final String format;
  final String length;
  final String chatScope;
  final String apiKey;
  final String customPrompt;
  /// `ltr` or `rtl` for Summary tab text.
  final String summaryTextDirection;
  final FolioAiProvider aiProvider;
  final String onDeviceModelId;
  final ThemeMode themeMode;

  bool get hasApiKey => apiKey.trim().isNotEmpty;

  bool get usesOnDeviceAi => aiProvider == FolioAiProvider.onDevice;

  bool get summaryIsRtl => summaryTextDirection.toLowerCase() == 'rtl';

  OnDeviceModel get onDeviceModel => OnDeviceModels.byId(onDeviceModelId);

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
    String? onDeviceModelId,
    ThemeMode? themeMode,
  }) {
    return FolioSettings(
      format: format ?? this.format,
      length: length ?? this.length,
      chatScope: chatScope ?? this.chatScope,
      apiKey: apiKey ?? this.apiKey,
      customPrompt: customPrompt ?? this.customPrompt,
      summaryTextDirection: summaryTextDirection ?? this.summaryTextDirection,
      aiProvider: aiProvider ?? this.aiProvider,
      onDeviceModelId: onDeviceModelId ?? this.onDeviceModelId,
      themeMode: themeMode ?? this.themeMode,
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
        'onDeviceModelId': onDeviceModelId,
        'themeMode': ThemeCubit.storageValue(themeMode),
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
      onDeviceModelId: () {
        final id = (json['onDeviceModelId'] as String?)?.trim() ?? '';
        if (id.isEmpty) return OnDeviceModels.fallbackDefaultId;
        if (OnDeviceModels.catalog.isEmpty) return id;
        return OnDeviceModels.byId(id).id;
      }(),
      themeMode: ThemeCubit.parse(json['themeMode'] as String?),
    );
  }
}
