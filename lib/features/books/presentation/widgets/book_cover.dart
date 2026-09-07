import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nexus_chat/core/theme/folio_colors.dart';
import 'package:nexus_chat/features/books/domain/book.dart';

/// Cover thumbnail: PDF page-1 image, or Folio branded placeholder.
class BookCover extends StatelessWidget {
  const BookCover({
    super.key,
    required this.book,
    this.width,
    this.height,
    this.borderRadius = 8,
    this.showTitleOnPlaceholder = true,
  });

  final Book book;
  final double? width;
  final double? height;
  final double borderRadius;
  final bool showTitleOnPlaceholder;

  @override
  Widget build(BuildContext context) {
    final path = book.coverPath;
    final hasFile = path != null && path.isNotEmpty && File(path).existsSync();

    final content = hasFile
        ? Image.file(
            File(path),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, _, _) => _Placeholder(
              title: book.title,
              showTitle: showTitleOnPlaceholder,
            ),
          )
        : _Placeholder(
            title: book.title,
            showTitle: showTitleOnPlaceholder,
          );

    final sized = width != null && height != null
        ? SizedBox(width: width, height: height, child: content)
        : SizedBox(
            width: width,
            height: height,
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: content,
            ),
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: sized,
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.title, required this.showTitle});

  final String title;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            FolioColors.surfaceElevated,
            FolioColors.background,
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.menu_book_rounded,
                  color: FolioColors.accent,
                  size: 36,
                ),
                if (showTitle) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: 120,
                    child: Text(
                      title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        color: FolioColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
