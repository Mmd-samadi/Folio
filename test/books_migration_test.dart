import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_chat/core/storage/local_store.dart';
import 'package:nexus_chat/features/books/domain/book.dart';
import 'package:nexus_chat/features/books/presentation/cubit/books_cubit.dart';
import 'package:nexus_chat/features/import/data/pdf_import_service.dart';
import 'package:nexus_chat/features/sessions/domain/reading_session.dart';
import 'package:nexus_chat/features/sessions/presentation/cubit/sessions_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('migrates flat sessions into books by localPath', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.open();
    final now = DateTime(2026, 3, 1);
    final sessions = SessionsCubit(
      store: store,
      seed: [
        ReadingSession(
          id: 's1',
          title: 'Intro',
          pdfName: 'guide.pdf',
          fromPage: 1,
          toPage: 3,
          updatedAt: now,
          localPath: '/docs/guide.pdf',
        ),
        ReadingSession(
          id: 's2',
          title: 'Middle',
          pdfName: 'guide.pdf',
          fromPage: 4,
          toPage: 6,
          updatedAt: now,
          localPath: '/docs/guide.pdf',
        ),
        ReadingSession(
          id: 's3',
          title: 'Other',
          pdfName: 'other.pdf',
          fromPage: 1,
          toPage: 2,
          updatedAt: now,
          localPath: '/docs/other.pdf',
        ),
      ],
    );
    await store.saveSessions(sessions.state);

    final books = BooksCubit(store: store, sessions: sessions);
    await books.hydrate();

    expect(books.state.length, 2);
    expect(sessions.state.every((s) => s.hasBook), isTrue);

    final guideBookId =
        sessions.state.firstWhere((s) => s.title == 'Intro').bookId!;
    expect(books.partsFor(guideBookId).length, 2);
    expect(Book.titleFromPdfName('my_book.pdf'), 'my book');
    expect(
      PdfImportService.coverPathForPdf('/docs/books/1/original.pdf'),
      '/docs/books/1/cover.png',
    );
  });
}
