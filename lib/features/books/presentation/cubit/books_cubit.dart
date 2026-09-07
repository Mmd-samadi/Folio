import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexus_chat/core/storage/local_store.dart';
import 'package:nexus_chat/features/books/domain/book.dart';
import 'package:nexus_chat/features/import/data/pdf_import_service.dart';
import 'package:nexus_chat/features/sessions/domain/reading_session.dart';
import 'package:nexus_chat/features/sessions/presentation/cubit/sessions_cubit.dart';

class BooksCubit extends Cubit<List<Book>> {
  BooksCubit({
    required this._store,
    required this._sessions,
    List<Book>? seed,
  }) : super(seed ?? const []);

  final LocalStore _store;
  final SessionsCubit _sessions;

  Future<void> hydrate() async {
    var books = _store.loadBooks();
    final sessions = _sessions.state;
    final migrated = _migrateIfNeeded(books: books, sessions: sessions);
    if (migrated != null) {
      books = migrated.books;
      await _store.saveBooks(books);
      await _sessions.replaceAll(migrated.sessions);
    }
    books = await _ensureCovers(books);
    emit(books);
  }

  /// Renders or reuses page-1 cover PNGs for books missing a valid cover file.
  Future<List<Book>> _ensureCovers(List<Book> books) async {
    var changed = false;
    final next = <Book>[];

    for (final book in books) {
      final existing = book.coverPath;
      if (existing != null &&
          existing.isNotEmpty &&
          File(existing).existsSync()) {
        next.add(book);
        continue;
      }

      final pdfPath = book.sourcePdfPath;
      if (pdfPath.isEmpty || !File(pdfPath).existsSync()) {
        next.add(book);
        continue;
      }

      final outPath = PdfImportService.coverPathForPdf(pdfPath);
      if (File(outPath).existsSync()) {
        next.add(book.copyWith(coverPath: outPath));
        changed = true;
        continue;
      }

      final rendered =
          await PdfImportService.renderCoverPng(pdfPath, outPath);
      if (rendered != null) {
        next.add(book.copyWith(coverPath: rendered));
        changed = true;
      } else {
        next.add(book);
      }
    }

    if (changed) {
      await _store.saveBooks(next);
    }
    return next;
  }

  Book? byId(String id) {
    for (final b in state) {
      if (b.id == id) return b;
    }
    return null;
  }

  List<ReadingSession> partsFor(String bookId) {
    return _sessions.state.where((s) => s.bookId == bookId).toList()
      ..sort((a, b) => a.fromPage.compareTo(b.fromPage));
  }

  double overallProgress(String bookId) {
    final parts = partsFor(bookId);
    if (parts.isEmpty) return 0;
    final sum = parts.fold<double>(0, (acc, p) => acc + p.progress);
    return (sum / parts.length).clamp(0.0, 1.0);
  }

  /// Registers a new book and its Folio parts in one step.
  Future<void> addBookWithParts({
    required Book book,
    required List<ReadingSession> parts,
  }) async {
    final stamped = [
      for (final p in parts)
        p.copyWith(
          bookId: book.id,
          localPath: p.localPath ?? book.sourcePdfPath,
          pdfName: p.pdfName.isEmpty ? book.pdfName : p.pdfName,
        ),
    ];
    emit([book, ...state.where((b) => b.id != book.id)]);
    await _persist();
    await _sessions.addAll(stamped);
  }

  Future<void> rename(String id, String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    emit([
      for (final b in state)
        if (b.id == id)
          b.copyWith(title: trimmed, updatedAt: DateTime.now())
        else
          b,
    ]);
    await _persist();
  }

  Future<void> deleteBook(String id) async {
    emit(state.where((b) => b.id != id).toList());
    await _persist();
    await _sessions.deleteByBookId(id);
    await PdfImportService.deleteBookFolder(id);
  }

  Future<void> clearAll() async {
    final ids = state.map((b) => b.id).toList();
    emit(const []);
    await _persist();
    await _sessions.clearAll();
    for (final id in ids) {
      await PdfImportService.deleteBookFolder(id);
    }
  }

  Future<void> _persist() => _store.saveBooks(state);

  /// Groups legacy flat sessions into Books by localPath / pdfName.
  _MigrationResult? _migrateIfNeeded({
    required List<Book> books,
    required List<ReadingSession> sessions,
  }) {
    final real = sessions.where((s) => s.hasLocalPdf).toList();
    if (real.isEmpty && books.isEmpty) return null;

    final bookIds = {for (final b in books) b.id};
    final needsMigrate = real.any((s) => !s.hasBook || !bookIds.contains(s.bookId));
    if (!needsMigrate && real.length == sessions.length) return null;

    final existingById = {for (final b in books) b.id: b};
    final nextBooks = <Book>[...books];
    final nextSessions = <ReadingSession>[];

    // Keep sessions that already have a valid book.
    final orphanGroups = <String, List<ReadingSession>>{};
    for (final s in real) {
      if (s.hasBook && existingById.containsKey(s.bookId)) {
        nextSessions.add(s);
        continue;
      }
      final key = (s.localPath != null && s.localPath!.isNotEmpty)
          ? 'path:${s.localPath}'
          : 'name:${s.pdfName}';
      orphanGroups.putIfAbsent(key, () => []).add(s);
    }

    for (final group in orphanGroups.values) {
      final sample = group.first;
      final bookId = sample.hasBook && sample.bookId!.isNotEmpty
          ? sample.bookId!
          : 'migrated_${DateTime.now().microsecondsSinceEpoch}_${nextBooks.length}';
      final updatedAt = group
          .map((s) => s.updatedAt)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      final createdAt = group
          .map((s) => s.updatedAt)
          .reduce((a, b) => a.isBefore(b) ? a : b);

      if (!existingById.containsKey(bookId)) {
        final book = Book(
          id: bookId,
          title: Book.titleFromPdfName(sample.pdfName),
          pdfName: sample.pdfName,
          sourcePdfPath: sample.localPath ?? '',
          coverPath: null,
          createdAt: createdAt,
          updatedAt: updatedAt,
        );
        nextBooks.add(book);
        existingById[bookId] = book;
      }

      for (final s in group) {
        nextSessions.add(s.copyWith(bookId: bookId));
      }
    }

    // Drop books with no parts after migration.
    final usedIds = nextSessions.map((s) => s.bookId).whereType<String>().toSet();
    final prunedBooks = nextBooks.where((b) => usedIds.contains(b.id)).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return _MigrationResult(books: prunedBooks, sessions: nextSessions);
  }
}

class _MigrationResult {
  const _MigrationResult({required this.books, required this.sessions});

  final List<Book> books;
  final List<ReadingSession> sessions;
}
