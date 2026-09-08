import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nexus_chat/core/theme/folio_colors.dart';
import 'package:nexus_chat/features/reader/domain/summarize_eta.dart';
import 'package:nexus_chat/features/reader/presentation/cubit/summarize_job_cubit.dart';
import 'package:nexus_chat/features/sessions/domain/reading_session.dart';

class SessionCard extends StatelessWidget {
  const SessionCard({
    super.key,
    required this.session,
    required this.onTap,
    required this.onMenuSelected,
    this.job,
    this.anyJobRunning = false,
  });

  final ReadingSession session;
  final VoidCallback onTap;
  final ValueChanged<String> onMenuSelected;
  final SummarizeJobState? job;
  final bool anyJobRunning;

  bool get _thisSummarizing => job?.sessionId == session.id;

  @override
  Widget build(BuildContext context) {
    final summarizeBlocked = anyJobRunning && !_thisSummarizing;

    return Material(
      color: FolioColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FolioColors.radiusCard),
        side: const BorderSide(color: FolioColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _thisSummarizing ? null : onTap,
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
                    enabled: !_thisSummarizing,
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
                        enabled: !summarizeBlocked,
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
              if (_thisSummarizing && job != null) ...[
                const SizedBox(height: 14),
                _SummarizeEtaIndicator(job: job!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SummarizeEtaIndicator extends StatefulWidget {
  const _SummarizeEtaIndicator({required this.job});

  final SummarizeJobState job;

  @override
  State<_SummarizeEtaIndicator> createState() => _SummarizeEtaIndicatorState();
}

class _SummarizeEtaIndicatorState extends State<_SummarizeEtaIndicator> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed =
        DateTime.now().difference(widget.job.startedAt).inSeconds.clamp(0, 9999);
    final eta = widget.job.etaSeconds;
    final progress = (elapsed / eta).clamp(0.0, 0.9);

    return Row(
      children: [
        SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(
            value: progress,
            strokeWidth: 3,
            color: FolioColors.accent,
            backgroundColor: FolioColors.surfaceElevated,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Summarizing…',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: FolioColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'About ${SummarizeEta.label(eta)} · ${elapsed}s elapsed',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: FolioColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
