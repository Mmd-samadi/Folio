import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nexus_chat/core/theme/folio_colors.dart';
import 'package:nexus_chat/core/widgets/folio_buttons.dart';
import 'package:nexus_chat/features/sessions/domain/reading_session.dart';

/// Shown when TOC cannot be detected — redirects to manual range.
class ChapterEmptyPage extends StatelessWidget {
  const ChapterEmptyPage({
    super.key,
    required this.pdfName,
    this.localPath,
  });

  final String pdfName;
  final String? localPath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FolioColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(
          pdfName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No chapters found',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "We couldn't detect a table of contents automatically.",
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: FolioColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: FolioColors.warningBg,
                  borderRadius: BorderRadius.circular(FolioColors.radiusCard),
                  border: Border.all(color: FolioColors.warningBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: FolioColors.warningText,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No table of contents found',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: FolioColors.warningText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Set page ranges manually to divide your reading.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: FolioColors.warningText.withValues(
                                alpha: 0.85,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(20),
              child: FolioPrimaryButton(
                label: 'Set Ranges Manually',
                onPressed: () {
                  context.pushReplacement('/manual-range', extra: {
                    'pdfName': pdfName,
                    'localPath': localPath,
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChapterFoundPage extends StatefulWidget {
  const ChapterFoundPage({
    super.key,
    required this.pdfName,
    this.localPath,
    required this.chapters,
  });

  final String pdfName;
  final String? localPath;
  final List<DetectedChapter> chapters;

  @override
  State<ChapterFoundPage> createState() => _ChapterFoundPageState();
}

class _ChapterFoundPageState extends State<ChapterFoundPage> {
  late final List<DetectedChapter> _chapters = List.of(widget.chapters);

  @override
  Widget build(BuildContext context) {
    final selected = _chapters.where((c) => c.selected).toList();

    return Scaffold(
      backgroundColor: FolioColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.pdfName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chapters detected',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select page ranges to auto-create reading sessions.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: FolioColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _chapters.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final chapter = _chapters[index];
                  return Material(
                    color: FolioColors.surfaceElevated,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(FolioColors.radiusCard),
                      side: const BorderSide(color: FolioColors.border),
                    ),
                    child: CheckboxListTile(
                      value: chapter.selected,
                      activeColor: FolioColors.accent,
                      checkColor: FolioColors.onAccent,
                      title: Text(
                        chapter.title,
                        style: GoogleFonts.inter(fontSize: 14),
                      ),
                      secondary: Text(
                        'pp. ${chapter.fromPage}–${chapter.toPage}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: FolioColors.textSecondary,
                        ),
                      ),
                      onChanged: (v) {
                        setState(() {
                          _chapters[index] =
                              chapter.copyWith(selected: v ?? false);
                        });
                      },
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: FolioPrimaryButton(
                label: 'Create Sessions',
                onPressed: selected.isEmpty
                    ? null
                    : () {
                        context.pop(selected);
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
