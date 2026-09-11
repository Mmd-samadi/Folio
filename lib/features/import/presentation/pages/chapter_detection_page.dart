import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:folio/core/theme/folio_colors.dart';
import 'package:folio/core/widgets/folio_buttons.dart';
import 'package:folio/features/books/domain/book.dart';
import 'package:folio/features/books/presentation/cubit/books_cubit.dart';
import 'package:folio/features/sessions/domain/reading_session.dart';

/// Shown when TOC cannot be detected — redirects to manual range.
class ChapterEmptyPage extends StatelessWidget {
  const ChapterEmptyPage({
    super.key,
    required this.pdfName,
    this.bookId,
    this.localPath,
    this.coverPath,
  });

  final String? bookId;
  final String pdfName;
  final String? localPath;
  final String? coverPath;

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
                    "We couldn't detect topics automatically for this window.",
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
                    Icon(
                      Icons.warning_amber_rounded,
                      color: FolioColors.warningText,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Try another page window',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: FolioColors.warningText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Detect headings across the book, or set ranges manually.',
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
              child: Column(
                children: [
                  FolioPrimaryButton(
                    label: 'Detect headings',
                    onPressed: () {
                      context.pushReplacement('/detect-topics', extra: {
                        'bookId': bookId,
                        'pdfName': pdfName,
                        'localPath': localPath,
                        'coverPath': coverPath,
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  FolioSecondaryButton(
                    label: 'Set Ranges Manually',
                    onPressed: () {
                      context.pushReplacement('/manual-range', extra: {
                        'bookId': bookId,
                        'pdfName': pdfName,
                        'localPath': localPath,
                        'coverPath': coverPath,
                      });
                    },
                  ),
                ],
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
    this.bookId,
    this.localPath,
    this.coverPath,
    required this.chapters,
    this.windowFrom,
    this.windowTo,
    this.notes,
  });

  final String? bookId;
  final String pdfName;
  final String? localPath;
  final String? coverPath;
  final List<DetectedChapter> chapters;
  final int? windowFrom;
  final int? windowTo;
  final String? notes;

  @override
  State<ChapterFoundPage> createState() => _ChapterFoundPageState();
}

class _ChapterFoundPageState extends State<ChapterFoundPage> {
  late final List<DetectedChapter> _chapters = List.of(widget.chapters);

  Future<void> _createSessions() async {
    final selected = _chapters.where((c) => c.selected).toList();
    if (selected.isEmpty) return;

    final bookId = widget.bookId?.isNotEmpty == true
        ? widget.bookId!
        : DateTime.now().microsecondsSinceEpoch.toString();
    final now = DateTime.now();
    final book = Book(
      id: bookId,
      title: Book.titleFromPdfName(widget.pdfName),
      pdfName: widget.pdfName,
      sourcePdfPath: widget.localPath ?? '',
      coverPath: widget.coverPath,
      createdAt: now,
      updatedAt: now,
    );

    final sessions = [
      for (final chapter in selected)
        ReadingSession(
          id: '${DateTime.now().microsecondsSinceEpoch}_${chapter.fromPage}',
          title: chapter.title,
          pdfName: widget.pdfName,
          fromPage: chapter.fromPage,
          toPage: chapter.toPage,
          updatedAt: now,
          progress: 0,
          localPath: widget.localPath,
          bookId: bookId,
        ),
    ];

    await context.read<BooksCubit>().addBookWithParts(
          book: book,
          parts: sessions,
        );
    if (!mounted) return;
    context.go('/book/$bookId');
  }

  @override
  Widget build(BuildContext context) {
    final selected = _chapters.where((c) => c.selected).toList();
    final windowLabel = widget.windowFrom != null && widget.windowTo != null
        ? 'Topics detected for pages ${widget.windowFrom}–${widget.windowTo}.'
        : 'Select topics to add as sections in this book.';

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
                    'Topics detected',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    windowLabel,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: FolioColors.textSecondary,
                    ),
                  ),
                  if (widget.notes != null && widget.notes!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      widget.notes!,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: FolioColors.textDim,
                      ),
                    ),
                  ],
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
                      side: BorderSide(color: FolioColors.border),
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
                label: selected.isEmpty
                    ? 'Add to Book'
                    : 'Add ${selected.length} section${selected.length == 1 ? '' : 's'}',
                onPressed: selected.isEmpty ? null : _createSessions,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
