import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:folio/core/theme/folio_colors.dart';
import 'package:folio/core/widgets/folio_buttons.dart';

Future<void> showImportPdfSheet(
  BuildContext context, {
  required VoidCallback onSelectFromDevice,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: FolioColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(FolioColors.radiusSheet),
      ),
    ),
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FolioSheetHandle(),
              const SizedBox(height: 20),
              Text(
                'Import PDF',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: FolioColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                height: 160,
                decoration: BoxDecoration(
                  color: FolioColors.surfaceElevated,
                  borderRadius:
                      BorderRadius.circular(FolioColors.radiusCard),
                ),
                child: CustomPaint(
                  painter: _DashedBorderPainter(color: FolioColors.border),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: FolioColors.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: FolioColors.border),
                          ),
                          child: Icon(
                            Icons.upload_outlined,
                            color: FolioColors.textPrimary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Tap to select PDF',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: FolioColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Supported: PDF files only',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: FolioColors.textDim,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FolioPrimaryButton(
                label: 'Select from device',
                onPressed: () {
                  Navigator.of(context).pop();
                  onSelectFromDevice();
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const dash = 6.0;
    const gap = 4.0;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(FolioColors.radiusCard),
        ),
      );

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dash;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
