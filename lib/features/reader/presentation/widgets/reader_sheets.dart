import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:folio/core/theme/folio_colors.dart';
import 'package:folio/core/widgets/folio_buttons.dart';
import 'package:folio/features/reader/data/folio_ai_service.dart';
import 'package:share_plus/share_plus.dart';

Future<void> showAnnotationSheet(
  BuildContext context, {
  required String quote,
  required ValueChanged<String> onSave,
}) {
  final noteController = TextEditingController();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: FolioColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(FolioColors.radiusSheet),
      ),
    ),
    builder: (context) {
      final bottom = MediaQuery.viewInsetsOf(context).bottom;
      return Padding(
        padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FolioSheetHandle(),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FolioColors.surfaceElevated,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 3,
                    height: 48,
                    decoration: BoxDecoration(
                      color: FolioColors.accent,
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '"$quote"',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Your note',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: FolioColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: noteController,
              maxLines: 4,
              decoration: const InputDecoration(hintText: 'Add a note...'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FolioSecondaryButton(
                    label: 'Cancel',
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FolioPrimaryButton(
                    label: 'Save Note',
                    height: 44,
                    onPressed: () {
                      onSave(noteController.text.trim());
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

Future<String?> showPromptEditorSheet(
  BuildContext context, {
  required String currentPrompt,
}) {
  final controller = TextEditingController(text: currentPrompt);
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: FolioColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(FolioColors.radiusSheet),
      ),
    ),
    builder: (context) {
      final bottom = MediaQuery.viewInsetsOf(context).bottom;
      return Padding(
        padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FolioSheetHandle(),
            const SizedBox(height: 16),
            Text(
              'Summarization Prompt',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 6,
              style: GoogleFonts.inter(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () {
                  controller.text = FolioAiService.defaultPrompt;
                },
                child: Text(
                  'Reset to default',
                  style: GoogleFonts.inter(
                    decoration: TextDecoration.underline,
                    color: FolioColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FolioSecondaryButton(
                    label: 'Cancel',
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FolioPrimaryButton(
                    label: 'Save prompt',
                    height: 44,
                    onPressed: () =>
                        Navigator.pop(context, controller.text.trim()),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

/// Returns the prompt to use for regenerate, or null if cancelled.
Future<String?> showRegenerateWithPromptSheet(
  BuildContext context, {
  required String pageRangeLabel,
  required String currentPrompt,
}) {
  final controller = TextEditingController(text: currentPrompt);
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: FolioColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(FolioColors.radiusSheet),
      ),
    ),
    builder: (context) {
      final bottom = MediaQuery.viewInsetsOf(context).bottom;
      return Padding(
        padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FolioSheetHandle(),
            const SizedBox(height: 16),
            Text(
              'Regenerate summary',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              pageRangeLabel,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: FolioColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Prompt',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: FolioColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              maxLines: 6,
              style: GoogleFonts.inter(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () {
                  controller.text = FolioAiService.defaultPrompt;
                },
                child: Text(
                  'Reset to default',
                  style: GoogleFonts.inter(
                    decoration: TextDecoration.underline,
                    color: FolioColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FolioSecondaryButton(
                    label: 'Cancel',
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FolioPrimaryButton(
                    label: 'Regenerate',
                    height: 44,
                    onPressed: () {
                      final next = controller.text.trim();
                      Navigator.pop(
                        context,
                        next.isEmpty ? FolioAiService.defaultPrompt : next,
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

enum ExportFormat { plainText, pdf, markdown }

Future<void> showExportSheet(
  BuildContext context, {
  required List<String> bullets,
  required String title,
}) {
  var selected = ExportFormat.pdf;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: FolioColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(FolioColors.radiusSheet),
      ),
    ),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          Widget option({
            required ExportFormat format,
            required IconData icon,
            required String label,
            required String subtitle,
          }) {
            final active = selected == format;
            return Material(
              color: FolioColors.surfaceElevated,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(FolioColors.radiusCard),
                side: BorderSide(
                  color: active ? FolioColors.accent : FolioColors.border,
                  width: active ? 2 : 1,
                ),
              ),
              child: InkWell(
                onTap: () => setModalState(() => selected = format),
                borderRadius: BorderRadius.circular(FolioColors.radiusCard),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: FolioColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: FolioColors.border),
                        ),
                        child: Icon(icon, size: 20),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              subtitle,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: FolioColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const FolioSheetHandle(),
                  const SizedBox(height: 16),
                  Text(
                    'Export Summary',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  option(
                    format: ExportFormat.plainText,
                    icon: Icons.description_outlined,
                    label: 'Plain Text',
                    subtitle: 'Export as .txt file',
                  ),
                  const SizedBox(height: 8),
                  option(
                    format: ExportFormat.pdf,
                    icon: Icons.picture_as_pdf_outlined,
                    label: 'PDF',
                    subtitle: 'Export as formatted PDF',
                  ),
                  const SizedBox(height: 8),
                  option(
                    format: ExportFormat.markdown,
                    icon: Icons.code,
                    label: 'Markdown',
                    subtitle: 'Export as .md file',
                  ),
                  const SizedBox(height: 20),
                  FolioPrimaryButton(
                    label: 'Export',
                    onPressed: () async {
                      final body = switch (selected) {
                        ExportFormat.markdown =>
                          '# $title\n\n${bullets.map((b) => '- $b').join('\n')}',
                        ExportFormat.plainText || ExportFormat.pdf =>
                          '$title\n\n${bullets.map((b) => '• $b').join('\n\n')}',
                      };
                      await Clipboard.setData(ClipboardData(text: body));
                      await SharePlus.instance.share(
                        ShareParams(text: body, subject: title),
                      );
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class SummarizeRangeRequest {
  const SummarizeRangeRequest({required this.fromPage, required this.toPage});

  final int fromPage;
  final int toPage;
}

/// Ask the user which PDF pages to summarize.
Future<SummarizeRangeRequest?> showSummarizeRangeSheet(
  BuildContext context, {
  required int initialFrom,
  required int initialTo,
  required int pageCount,
}) {
  final fromController = TextEditingController(text: '$initialFrom');
  final toController = TextEditingController(text: '$initialTo');
  String? error;

  return showModalBottomSheet<SummarizeRangeRequest>(
    context: context,
    isScrollControlled: true,
    backgroundColor: FolioColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(FolioColors.radiusSheet),
      ),
    ),
    builder: (context) {
      final bottom = MediaQuery.viewInsetsOf(context).bottom;
      return StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const FolioSheetHandle(),
                const SizedBox(height: 16),
                Text(
                  'Summarize pages',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Pick a page range from the PDF. Smaller ranges work better '
                  'with on-device models.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.4,
                    color: FolioColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: fromController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(labelText: 'From'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: toController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(labelText: 'To'),
                      ),
                    ),
                  ],
                ),
                if (pageCount > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    'PDF has $pageCount pages',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: FolioColors.textDim,
                    ),
                  ),
                ],
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    error!,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: FolioColors.danger,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FolioSecondaryButton(
                        label: 'Cancel',
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FolioPrimaryButton(
                        label: 'Summarize',
                        height: 44,
                        onPressed: () {
                          final from = int.tryParse(fromController.text.trim());
                          final to = int.tryParse(toController.text.trim());
                          if (from == null || to == null || from < 1 || to < from) {
                            setModalState(() {
                              error = 'Enter a valid from–to range.';
                            });
                            return;
                          }
                          if (pageCount > 0 && to > pageCount) {
                            setModalState(() {
                              error = 'To page cannot exceed $pageCount.';
                            });
                            return;
                          }
                          Navigator.pop(
                            context,
                            SummarizeRangeRequest(fromPage: from, toPage: to),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
