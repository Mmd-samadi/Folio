import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nexus_chat/core/theme/folio_colors.dart';
import 'package:nexus_chat/features/books/domain/book.dart';
import 'package:nexus_chat/features/books/presentation/cubit/books_cubit.dart';
import 'package:nexus_chat/features/books/presentation/widgets/book_cover.dart';
import 'package:nexus_chat/features/chat/data/api_exception.dart';
import 'package:nexus_chat/features/chat/data/network_exception.dart';
import 'package:nexus_chat/features/reader/data/section_summarizer.dart';
import 'package:nexus_chat/features/reader/domain/summarize_eta.dart';
import 'package:nexus_chat/features/reader/presentation/cubit/summarize_job_cubit.dart';
import 'package:nexus_chat/features/sessions/domain/reading_session.dart';
import 'package:nexus_chat/features/sessions/presentation/cubit/sessions_cubit.dart';
import 'package:nexus_chat/features/sessions/presentation/widgets/session_card.dart';
import 'package:nexus_chat/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:nexus_chat/features/settings/presentation/widgets/api_key_gate_sheet.dart';

class BookFolderPage extends StatefulWidget {
  const BookFolderPage({super.key, required this.bookId});

  final String bookId;

  @override
  State<BookFolderPage> createState() => _BookFolderPageState();
}

class _BookFolderPageState extends State<BookFolderPage> {
  Future<void> _renameBook(Book book) async {
    final controller = TextEditingController(text: book.title);
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: FolioColors.surface,
          title: Text(
            'Rename book',
            style: GoogleFonts.inter(color: FolioColors.textPrimary),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: GoogleFonts.inter(color: FolioColors.textPrimary),
            decoration: const InputDecoration(hintText: 'Book title'),
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
    if (result != null && result.trim().isNotEmpty && mounted) {
      await context.read<BooksCubit>().rename(book.id, result);
    }
  }

  Future<void> _confirmDeleteBook(Book book) async {
    final parts = context.read<BooksCubit>().partsFor(book.id);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: FolioColors.surface,
          title: Text(
            'Delete book?',
            style: GoogleFonts.inter(color: FolioColors.textPrimary),
          ),
          content: Text(
            '“${book.title}” and its ${parts.length} section'
            '${parts.length == 1 ? '' : 's'} will be removed.',
            style: GoogleFonts.inter(color: FolioColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(color: FolioColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'Delete',
                style: GoogleFonts.inter(color: FolioColors.danger),
              ),
            ),
          ],
        );
      },
    );
    if (ok == true && mounted) {
      await context.read<BooksCubit>().deleteBook(book.id);
      if (mounted) context.go('/home');
    }
  }

  Future<void> _renamePart(ReadingSession session) async {
    final controller = TextEditingController(text: session.title);
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: FolioColors.surface,
          title: Text(
            'Rename section',
            style: GoogleFonts.inter(color: FolioColors.textPrimary),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: GoogleFonts.inter(color: FolioColors.textPrimary),
            decoration: const InputDecoration(hintText: 'Section title'),
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
    if (result != null && result.trim().isNotEmpty && mounted) {
      await context.read<SessionsCubit>().rename(session.id, result);
    }
  }

  Future<void> _summarizePart(
    ReadingSession session, {
    bool force = false,
  }) async {
    final jobCubit = context.read<SummarizeJobCubit>();
    if (jobCubit.isBusy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Another summary is running')),
      );
      return;
    }

    if (session.hasSummary && !force) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Summary ready')),
      );
      return;
    }

    final ready = await ensureFolioAiReady(context);
    if (!mounted) return;
    if (!ready) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            folioAiNotReadyMessage(
              context.read<SettingsCubit>().state.aiProvider,
            ),
          ),
        ),
      );
      return;
    }

    var fileSize = 0;
    try {
      if (session.hasLocalPdf) {
        fileSize = await File(session.localPath!).length();
      }
    } catch (_) {}

    final eta = SummarizeEta.estimateSeconds(
      fromPage: session.fromPage,
      toPage: session.toPage,
      fileSizeBytes: fileSize,
    );

    final started = jobCubit.tryBegin(sessionId: session.id, etaSeconds: eta);
    if (!started) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Another summary is running')),
      );
      return;
    }

    if (!mounted) {
      jobCubit.end();
      return;
    }
    final sessions = context.read<SessionsCubit>();
    final settings = context.read<SettingsCubit>().state;
    final messenger = ScaffoldMessenger.of(context);

    try {
      await const SectionSummarizer().summarize(
        session: session,
        sessions: sessions,
        apiKey: settings.apiKey,
        format: settings.format,
        length: settings.length,
        customPrompt:
            settings.customPrompt.isEmpty ? null : settings.customPrompt,
        provider: settings.aiProvider,
        onDeviceModel: settings.onDeviceModel,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(force ? 'Summary updated' : 'Summary saved'),
        ),
      );
    } on NetworkException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } on ApiException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } on StateError catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Summarization failed: $e')),
      );
    } finally {
      jobCubit.end();
    }
  }

  void _openReader(String sessionId, {String? tab, int? page}) {
    context.push(
      '/reader/$sessionId',
      extra: {
        'tab': ?tab,
        'page': ?page,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BooksCubit, List<Book>>(
      builder: (context, books) {
        Book? book;
        for (final b in books) {
          if (b.id == widget.bookId) {
            book = b;
            break;
          }
        }

        if (book == null) {
          return Scaffold(
            backgroundColor: FolioColors.background,
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/home'),
              ),
            ),
            body: Center(
              child: Text(
                'Book not found',
                style: GoogleFonts.inter(color: FolioColors.textSecondary),
              ),
            ),
          );
        }

        final current = book;
        return BlocBuilder<SessionsCubit, List<ReadingSession>>(
          builder: (context, _) {
            return BlocBuilder<SummarizeJobCubit, SummarizeJobState?>(
              builder: (context, job) {
                final parts =
                    context.read<BooksCubit>().partsFor(widget.bookId);
                final progress =
                    context.read<BooksCubit>().overallProgress(widget.bookId);
                final progressPct = (progress * 100).round();

                return Scaffold(
                  backgroundColor: FolioColors.background,
                  appBar: AppBar(
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => context.go('/home'),
                    ),
                    actions: [
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        color: FolioColors.surface,
                        onSelected: (action) {
                          if (action == 'rename') {
                            _renameBook(current);
                          } else if (action == 'delete') {
                            _confirmDeleteBook(current);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'rename',
                            child: Text(
                              'Rename book',
                              style: GoogleFonts.inter(
                                color: FolioColors.textPrimary,
                              ),
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(
                              'Delete book',
                              style: GoogleFonts.inter(
                                color: FolioColors.danger,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  body: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                    children: [
                      Center(
                        child: SizedBox(
                          width: 160,
                          child: BookCover(
                            book: current,
                            borderRadius: 10,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        current.title,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: FolioColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${parts.length} section${parts.length == 1 ? '' : 's'}'
                        ' · $progressPct% read',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: FolioColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Sections',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: FolioColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (parts.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'No sections in this book yet.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: FolioColors.textSecondary,
                            ),
                          ),
                        )
                      else
                        for (var i = 0; i < parts.length; i++) ...[
                          if (i > 0) const SizedBox(height: 12),
                          SessionCard(
                            session: parts[i],
                            job: job,
                            anyJobRunning: job != null,
                            onTap: () => _openReader(parts[i].id),
                            onMenuSelected: (action) {
                              if (action == 'summarize') {
                                _summarizePart(parts[i]);
                              } else if (action == 'resummarize') {
                                _summarizePart(parts[i], force: true);
                              } else if (action == 'view_summary') {
                                _openReader(parts[i].id, tab: 'summary');
                              } else if (action == 'rename') {
                                _renamePart(parts[i]);
                              } else if (action == 'delete') {
                                context
                                    .read<SessionsCubit>()
                                    .delete(parts[i].id);
                              }
                            },
                          ),
                        ],
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
