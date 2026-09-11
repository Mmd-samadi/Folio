import 'package:flutter/material.dart';

/// Folio design tokens — bind from [ThemeData.extensions] via [bind].
abstract final class FolioColors {
  static FolioPalette _current = FolioPalette.dark;

  /// Call from MaterialApp.builder so static FolioColors.* track theme.
  static void bind(ThemeData theme) {
    _current = theme.extension<FolioPalette>() ??
        (theme.brightness == Brightness.light
            ? FolioPalette.light
            : FolioPalette.dark);
  }

  static FolioPalette of(BuildContext context) {
    return Theme.of(context).extension<FolioPalette>() ??
        (Theme.of(context).brightness == Brightness.light
            ? FolioPalette.light
            : FolioPalette.dark);
  }

  static Color get background => _current.background;
  static Color get surface => _current.surface;
  static Color get surfaceElevated => _current.surfaceElevated;
  static Color get border => _current.border;
  static Color get accent => _current.accent;
  static Color get onAccent => _current.onAccent;
  static Color get textPrimary => _current.textPrimary;
  static Color get textSecondary => _current.textSecondary;
  static Color get textDim => _current.textDim;
  static Color get warningBg => _current.warningBg;
  static Color get warningBorder => _current.warningBorder;
  static Color get warningText => _current.warningText;
  static Color get danger => _current.danger;
  static Color get offlineBg => _current.offlineBg;
  static Color get offlineText => _current.offlineText;
  static Color get pdfPage => _current.pdfPage;
  static Color get pdfText => _current.pdfText;

  static const radiusCard = 8.0;
  static const radiusButton = 4.0;
  static const radiusSheet = 12.0;
  static const radiusFab = 28.0;
}

@immutable
class FolioPalette extends ThemeExtension<FolioPalette> {
  const FolioPalette({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.border,
    required this.accent,
    required this.onAccent,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDim,
    required this.warningBg,
    required this.warningBorder,
    required this.warningText,
    required this.danger,
    required this.offlineBg,
    required this.offlineText,
    required this.pdfPage,
    required this.pdfText,
  });

  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color border;
  final Color accent;
  final Color onAccent;
  final Color textPrimary;
  final Color textSecondary;
  final Color textDim;
  final Color warningBg;
  final Color warningBorder;
  final Color warningText;
  final Color danger;
  final Color offlineBg;
  final Color offlineText;
  final Color pdfPage;
  final Color pdfText;

  static const dark = FolioPalette(
    background: Color(0xFF0A0A0A),
    surface: Color(0xFF141414),
    surfaceElevated: Color(0xFF1E1E1E),
    border: Color(0xFF2A2A2A),
    accent: Color(0xFF6C63FF),
    onAccent: Color(0xFFFFFFFF),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF888888),
    textDim: Color(0xFF444444),
    warningBg: Color(0xFF3A2A0A),
    warningBorder: Color(0xFFE6A23C),
    warningText: Color(0xFFFFD07B),
    danger: Color(0xFFE55C5C),
    offlineBg: Color(0xFF3A1A1A),
    offlineText: Color(0xFFFFB4B4),
    pdfPage: Color(0xFFF2F2F2),
    pdfText: Color(0xFF333333),
  );

  static const light = FolioPalette(
    background: Color(0xFFFAFAFA),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFF3F3F5),
    border: Color(0xFFE6E6EA),
    accent: Color(0xFF6C63FF),
    onAccent: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF121212),
    textSecondary: Color(0xFF6B6B6B),
    textDim: Color(0xFF9A9A9A),
    warningBg: Color(0xFFFFF6E5),
    warningBorder: Color(0xFFE6A23C),
    warningText: Color(0xFF8A5A00),
    danger: Color(0xFFD14343),
    offlineBg: Color(0xFFFFECEC),
    offlineText: Color(0xFF8B1A1A),
    pdfPage: Color(0xFFF2F2F2),
    pdfText: Color(0xFF333333),
  );

  @override
  FolioPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? border,
    Color? accent,
    Color? onAccent,
    Color? textPrimary,
    Color? textSecondary,
    Color? textDim,
    Color? warningBg,
    Color? warningBorder,
    Color? warningText,
    Color? danger,
    Color? offlineBg,
    Color? offlineText,
    Color? pdfPage,
    Color? pdfText,
  }) {
    return FolioPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      border: border ?? this.border,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textDim: textDim ?? this.textDim,
      warningBg: warningBg ?? this.warningBg,
      warningBorder: warningBorder ?? this.warningBorder,
      warningText: warningText ?? this.warningText,
      danger: danger ?? this.danger,
      offlineBg: offlineBg ?? this.offlineBg,
      offlineText: offlineText ?? this.offlineText,
      pdfPage: pdfPage ?? this.pdfPage,
      pdfText: pdfText ?? this.pdfText,
    );
  }

  @override
  FolioPalette lerp(ThemeExtension<FolioPalette>? other, double t) {
    if (other is! FolioPalette) return this;
    return FolioPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      border: Color.lerp(border, other.border, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textDim: Color.lerp(textDim, other.textDim, t)!,
      warningBg: Color.lerp(warningBg, other.warningBg, t)!,
      warningBorder: Color.lerp(warningBorder, other.warningBorder, t)!,
      warningText: Color.lerp(warningText, other.warningText, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      offlineBg: Color.lerp(offlineBg, other.offlineBg, t)!,
      offlineText: Color.lerp(offlineText, other.offlineText, t)!,
      pdfPage: Color.lerp(pdfPage, other.pdfPage, t)!,
      pdfText: Color.lerp(pdfText, other.pdfText, t)!,
    );
  }
}
