import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:folio/core/constants/app_constants.dart';
import 'package:folio/core/theme/folio_colors.dart';
import 'package:folio/core/widgets/folio_buttons.dart';
import 'package:folio/features/books/domain/book.dart';
import 'package:folio/features/books/presentation/cubit/books_cubit.dart';
import 'package:folio/features/books/presentation/widgets/book_card.dart';
import 'package:folio/features/import/data/pdf_import_service.dart';
import 'package:folio/features/sessions/domain/reading_session.dart';
import 'package:folio/features/sessions/presentation/cubit/sessions_cubit.dart';
import 'package:folio/features/sessions/presentation/widgets/import_pdf_sheet.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  var _searchOpen = false;
  var _query = '';
  var _offline = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initConnectivity();
  }

  Future<void> _initConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    _applyConnectivity(results);
    _connectivitySub = Connectivity().onConnectivityChanged.listen(
      _applyConnectivity,
    );
  }

  void _applyConnectivity(List<ConnectivityResult> results) {
    final offline = results.isEmpty ||
        results.every((r) => r == ConnectivityResult.none);
    if (!mounted) return;
    setState(() => _offline = offline);
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openImport() async {
    await showImportPdfSheet(
      context,
      onSelectFromDevice: _pickPdf,
    );
  }

  Future<void> _pickPdf() async {
    try {
      final picked = await PdfImportService().pickAndStore();
      if (picked == null || !mounted) return;

      await context.push(
        '/detect-topics',
        extra: {
          'bookId': picked.bookId,
          'pdfName': picked.originalName,
          'localPath': picked.localPath,
          'coverPath': picked.coverPath,
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not import PDF: $e')),
      );
    }
  }

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
    }
  }

  List<Book> _filter(List<Book> books) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return books;
    return books
        .where(
          (b) =>
              b.title.toLowerCase().contains(q) ||
              b.pdfName.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FolioColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: _searchOpen
                  ? Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            autofocus: true,
                            onChanged: (v) => setState(() => _query = v),
                            style: GoogleFonts.inter(
                              color: FolioColors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search books...',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.close, size: 20),
                                onPressed: () {
                                  setState(() {
                                    _searchOpen = false;
                                    _query = '';
                                    _searchController.clear();
                                  });
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        const SizedBox(width: 8),
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
                          onPressed: () => setState(() => _searchOpen = true),
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
            Divider(height: 1, color: FolioColors.border),
            if (_offline)
              Material(
                color: FolioColors.offlineBg,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "You're offline",
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: FolioColors.offlineText,
                              ),
                            ),
                            Text(
                              'Summaries and chat need a connection. Saved PDFs still open.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: FolioColors.offlineText
                                    .withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final results =
                              await Connectivity().checkConnectivity();
                          _applyConnectivity(results);
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: FolioColors.accent,
                          foregroundColor: FolioColors.onAccent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        child: Text(
                          'Retry',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: BlocBuilder<BooksCubit, List<Book>>(
                builder: (context, books) {
                  return BlocBuilder<SessionsCubit, List<ReadingSession>>(
                    builder: (context, _) {
                      final visible = _filter(books);
                      if (books.isEmpty) {
                        return _EmptyState(onImport: _openImport);
                      }
                      if (visible.isEmpty) {
                        return Center(
                          child: Text(
                            'No books match “$_query”',
                            style: GoogleFonts.inter(
                              color: FolioColors.textSecondary,
                            ),
                          ),
                        );
                      }
                      final cubit = context.read<BooksCubit>();
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                        itemCount: visible.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final book = visible[index];
                          final parts = cubit.partsFor(book.id);
                          return BookCard(
                            book: book,
                            sectionCount: parts.length,
                            progress: cubit.overallProgress(book.id),
                            onTap: () => context.push('/book/${book.id}'),
                            onMenuSelected: (action) {
                              if (action == 'rename') {
                                _renameBook(book);
                              } else if (action == 'delete') {
                                _confirmDeleteBook(book);
                              }
                            },
                          );
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
      floatingActionButton: BlocBuilder<BooksCubit, List<Book>>(
        builder: (context, books) {
          if (books.isEmpty) return const SizedBox.shrink();
          return FloatingActionButton(
            onPressed: _openImport,
            backgroundColor: FolioColors.accent,
            child: Icon(Icons.add, color: FolioColors.onAccent),
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
            child: Icon(
              Icons.menu_book_outlined,
              size: 40,
              color: FolioColors.accent,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No books yet',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: FolioColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Import a PDF to create a book. Topics become sections inside that book.',
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
