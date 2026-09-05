import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nexus_chat/core/theme/folio_colors.dart';

class AppTheme {
  AppTheme._();

  // Kept for existing chat widgets (reader chat will reuse later).
  static const userBubbleLight = FolioColors.accent;
  static const userBubbleDark = FolioColors.accent;
  static const assistantBubbleLight = FolioColors.surfaceElevated;
  static const assistantBubbleDark = FolioColors.surfaceElevated;

  static ThemeData get darkTheme {
    final baseText = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: FolioColors.background,
      colorScheme: const ColorScheme.dark(
        primary: FolioColors.accent,
        onPrimary: FolioColors.onAccent,
        secondary: FolioColors.accent,
        surface: FolioColors.surface,
        onSurface: FolioColors.textPrimary,
        error: FolioColors.danger,
        outline: FolioColors.border,
      ),
      textTheme: baseText.apply(
        bodyColor: FolioColors.textPrimary,
        displayColor: FolioColors.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: FolioColors.background,
        foregroundColor: FolioColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: FolioColors.textPrimary,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: FolioColors.border,
        thickness: 1,
        space: 1,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: FolioColors.accent,
        foregroundColor: FolioColors.onAccent,
        elevation: 4,
        shape: CircleBorder(),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: FolioColors.surfaceElevated,
        contentTextStyle: GoogleFonts.inter(
          color: FolioColors.textPrimary,
          fontSize: 14,
        ),
        actionTextColor: FolioColors.accent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: FolioColors.surfaceElevated,
        hintStyle: GoogleFonts.inter(
          color: FolioColors.textDim,
          fontSize: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FolioColors.radiusButton),
          borderSide: const BorderSide(color: FolioColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FolioColors.radiusButton),
          borderSide: const BorderSide(color: FolioColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FolioColors.radiusButton),
          borderSide: const BorderSide(color: FolioColors.accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: FolioColors.surface,
        modalBackgroundColor: FolioColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(FolioColors.radiusSheet),
          ),
        ),
      ),
    );
  }
}
