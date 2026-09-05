import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nexus_chat/core/theme/folio_colors.dart';
import 'package:nexus_chat/features/sessions/domain/reading_session.dart';

class SessionCard extends StatelessWidget {
  const SessionCard({
    super.key,
    required this.session,
    required this.onTap,
    required this.onMenuSelected,
  });

  final ReadingSession session;
  final VoidCallback onTap;
  final ValueChanged<String> onMenuSelected;

  @override
  Widget build(BuildContext context) {
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
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.title,
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: FolioColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          session.pdfName,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: FolioColors.textSecondary,
                          ),
                        ),
                      ],
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
                      borderRadius:
                          BorderRadius.circular(FolioColors.radiusCard),
                      side: const BorderSide(color: FolioColors.accent),
                    ),
                    onSelected: onMenuSelected,
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'rename',
                        child: Text(
                          'Rename',
                          style: GoogleFonts.inter(
                            color: FolioColors.textPrimary,
                          ),
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
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    session.pageRangeLabel,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: FolioColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    session.dateLabel,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: FolioColors.textDim,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: session.progress.clamp(0.0, 1.0),
                  minHeight: 3,
                  backgroundColor: FolioColors.surfaceElevated,
                  color: FolioColors.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
