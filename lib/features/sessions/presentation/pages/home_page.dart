import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nexus_chat/core/constants/app_constants.dart';
import 'package:nexus_chat/core/theme/folio_colors.dart';
import 'package:nexus_chat/core/widgets/folio_buttons.dart';
import 'package:nexus_chat/features/import/data/pdf_import_service.dart';
import 'package:nexus_chat/features/sessions/domain/reading_session.dart';
import 'package:nexus_chat/features/sessions/presentation/cubit/sessions_cubit.dart';
import 'package:nexus_chat/features/sessions/presentation/widgets/import_pdf_sheet.dart';
import 'package:nexus_chat/features/sessions/presentation/widgets/session_card.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> _openImport(BuildContext context) async {
    await showImportPdfSheet(
      context,
      onSelectFromDevice: () => _pickPdf(context),
    );
  }

  Future<void> _pickPdf(BuildContext context) async {
    try {
      final picked = await PdfImportService().pickAndStore();
      if (picked == null || !context.mounted) return;

      // Heuristic: large papers often have TOC → show chapter picker with
      // realistic sample chapters; otherwise go to empty/manual.
      final showToc = picked.bytes.length > 200 * 1024;
      if (showToc) {
        final selected = await context.push<List<DetectedChapter>>(
          '/chapters-found',
          extra: {
            'pdfName': picked.originalName,
            'localPath': picked.localPath,
            'chapters': [
              const DetectedChapter(
                title: 'Introduction & Motivation',
                fromPage: 1,
                toPage: 11,
              ),
              const DetectedChapter(
                title: 'The Transformer Model',
                fromPage: 12,
                toPage: 25,
              ),
              const DetectedChapter(
                title: 'Attention Mechanisms',
                fromPage: 26,
                toPage: 34,
              ),
              const DetectedChapter(
                title: 'Training and Dataset Details',
                fromPage: 35,
                toPage: 40,
                selected: false,
              ),
              const DetectedChapter(
                title: 'Experimental Evaluation',
                fromPage: 41,
                toPage: 45,
                selected: false,
              ),
            ],
          },
        );
        if (!context.mounted) return;
        if (selected == null || selected.isEmpty) return;

        for (final chapter in selected) {
          context.read<SessionsCubit>().add(
                ReadingSession(
                  id: '${DateTime.now().microsecondsSinceEpoch}_${chapter.fromPage}',
                  title: chapter.title,
                  pdfName: picked.originalName,
                  fromPage: chapter.fromPage,
                  toPage: chapter.toPage,
                  updatedAt: DateTime.now(),
                  localPath: picked.localPath,
                ),
              );
        }
        final first = selected.first;
        final sessions = context.read<SessionsCubit>().state;
        final created = sessions.firstWhere(
          (s) =>
              s.localPath == picked.localPath &&
              s.fromPage == first.fromPage &&
              s.title == first.title,
        );
        context.go('/reader/${created.id}');
      } else {
        await context.push(
          '/chapters-empty',
          extra: {
            'pdfName': picked.originalName,
            'localPath': picked.localPath,
          },
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not import PDF: $e')),
      );
    }
  }

  Future<void> _renameSession(
    BuildContext context,
    ReadingSession session,
  ) async {
    final controller = TextEditingController(text: session.title);
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: FolioColors.surface,
          title: Text(
            'Rename session',
            style: GoogleFonts.inter(color: FolioColors.textPrimary),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: GoogleFonts.inter(color: FolioColors.textPrimary),
            decoration: const InputDecoration(hintText: 'Session title'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(color: FolioColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: Text(
                'Save',
                style: GoogleFonts.inter(color: FolioColors.accent),
              ),
            ),
          ],
        );
      },
    );
    if (result != null && result.trim().isNotEmpty && context.mounted) {
      context.read<SessionsCubit>().rename(session.id, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FolioColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Text(
                    AppConstants.appTitle,
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: FolioColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.search, size: 22),
                    color: FolioColors.textPrimary,
                  ),
                  IconButton(
                    onPressed: () => context.push('/settings'),
                    icon: const Icon(Icons.settings_outlined, size: 22),
                    color: FolioColors.textPrimary,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: FolioColors.border),
            Expanded(
              child: BlocBuilder<SessionsCubit, List<ReadingSession>>(
                builder: (context, sessions) {
                  if (sessions.isEmpty) {
                    return _EmptyState(onImport: () => _openImport(context));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                    itemCount: sessions.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      return SessionCard(
                        session: session,
                        onTap: () => context.push('/reader/${session.id}'),
                        onMenuSelected: (action) {
                          if (action == 'rename') {
                            _renameSession(context, session);
                          } else if (action == 'delete') {
                            context.read<SessionsCubit>().delete(session.id);
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: BlocBuilder<SessionsCubit, List<ReadingSession>>(
        builder: (context, sessions) {
          if (sessions.isEmpty) return const SizedBox.shrink();
          return FloatingActionButton(
            onPressed: () => _openImport(context),
            backgroundColor: FolioColors.accent,
            child: const Icon(Icons.add, color: FolioColors.onAccent),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onImport});

  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: FolioColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: FolioColors.border),
            ),
            child: const Icon(
              Icons.menu_book_outlined,
              size: 40,
              color: FolioColors.accent,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No sessions yet',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: FolioColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Import a PDF to start reading smarter with AI summaries and focused sessions.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.5,
              color: FolioColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 220,
            child: FolioPrimaryButton(
              label: 'Import PDF',
              onPressed: onImport,
            ),
          ),
        ],
      ),
    );
  }
}
