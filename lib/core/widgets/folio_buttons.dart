import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:folio/core/theme/folio_colors.dart';

class FolioPrimaryButton extends StatelessWidget {
  const FolioPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 48,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: FolioColors.accent,
          foregroundColor: FolioColors.onAccent,
          disabledBackgroundColor: FolioColors.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FolioColors.radiusButton),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

class FolioSecondaryButton extends StatelessWidget {
  const FolioSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 44,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: FolioColors.textPrimary,
          side: BorderSide(color: FolioColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FolioColors.radiusButton),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

class FolioSheetHandle extends StatelessWidget {
  const FolioSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: FolioColors.textDim,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
