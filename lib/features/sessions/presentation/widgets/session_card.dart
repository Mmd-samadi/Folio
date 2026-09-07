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
    this.onSummarize,
    this.summarizing = false,
  });

  final ReadingSession session;
  final VoidCallback onTap;
  final ValueChanged<String> onMenuSelected;
  /// Runs AI summarize while staying on Book folder. Null hides the button.
  final VoidCallback? onSummarize;
  final bool summarizing;

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
        onTap: summarizing ? null : onTap,
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
                          session.pageRangeLabel,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: FolioColors.textSecondary,
                          ),
                        ),
                        if (session.hasSummary) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: FolioColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: FolioColors.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.check_circle_outline,
                                  size: 14,
                                  color: FolioColors.accent,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Summarized',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: FolioColors.accent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    enabled: !summarizing,
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
                        value: session.hasSummary ? 'resummarize' : 'summarize',
                        child: Text(
                          session.hasSummary ? 'Re-summarize' : 'Summarize',
                          style: GoogleFonts.inter(
                            color: FolioColors.textPrimary,
                          ),
                        ),
                      ),
                      if (session.hasSummary)
                        PopupMenuItem(
                          value: 'view_summary',
                          child: Text(
                            'View summary',
                            style: GoogleFonts.inter(
                              color: FolioColors.textPrimary,
                            ),
                          ),
                        ),
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
                    '${(session.progress * 100).round()}% read',
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
              if (onSummarize != null && !session.hasSummary) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 36,
                  child: OutlinedButton(
                    onPressed: summarizing ? null : onSummarize,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: FolioColors.accent,
                      side: const BorderSide(color: FolioColors.accent),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(FolioColors.radiusButton),
                      ),
                    ),
                    child: summarizing
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: FolioColors.accent,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Summarizing…',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            'Summarize',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
              if (onSummarize != null && session.hasSummary && summarizing) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: FolioColors.accent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Re-summarizing…',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: FolioColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
