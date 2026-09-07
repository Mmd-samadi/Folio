import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nexus_chat/core/theme/folio_colors.dart';
import 'package:nexus_chat/features/books/domain/book.dart';
import 'package:nexus_chat/features/books/presentation/widgets/book_cover.dart';

class BookCard extends StatelessWidget {
  const BookCard({
    super.key,
    required this.book,
    required this.sectionCount,
    required this.progress,
    required this.onTap,
    required this.onMenuSelected,
  });

  final Book book;
  final int sectionCount;
  final double progress;
  final VoidCallback onTap;
  final ValueChanged<String> onMenuSelected;

  @override
  Widget build(BuildContext context) {
    final sectionsLabel =
        '$sectionCount section${sectionCount == 1 ? '' : 's'}';
    final progressPct = (progress * 100).round();

    return Material(
      color: FolioColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FolioColors.radiusCard),
        side: const BorderSide(color: FolioColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BookCover(
                book: book,
                width: 72,
                height: 96,
                borderRadius: 6,
                showTitleOnPlaceholder: false,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: FolioColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$sectionsLabel · $progressPct%',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: FolioColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          minHeight: 3,
                          backgroundColor: FolioColors.surfaceElevated,
                          color: FolioColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert,
                  color: FolioColors.textSecondary,
                  size: 20,
                ),
                color: FolioColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(FolioColors.radiusCard),
                  side: const BorderSide(color: FolioColors.accent),
                ),
                onSelected: onMenuSelected,
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'rename',
                    child: Text(
                      'Rename',
                      style: GoogleFonts.inter(color: FolioColors.textPrimary),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Delete',
                      style: GoogleFonts.inter(color: FolioColors.danger),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
