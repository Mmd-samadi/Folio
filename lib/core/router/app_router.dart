import 'package:go_router/go_router.dart';
import 'package:nexus_chat/features/books/presentation/pages/book_folder_page.dart';
import 'package:nexus_chat/features/import/presentation/pages/chapter_detection_page.dart';
import 'package:nexus_chat/features/import/presentation/pages/manual_range_page.dart';
import 'package:nexus_chat/features/import/presentation/pages/topic_detect_page.dart';
import 'package:nexus_chat/features/reader/presentation/pages/reader_page.dart';
import 'package:nexus_chat/features/sessions/domain/reading_session.dart';
import 'package:nexus_chat/features/sessions/presentation/pages/home_page.dart';
import 'package:nexus_chat/features/sessions/presentation/pages/splash_page.dart';
import 'package:nexus_chat/features/settings/presentation/pages/settings_page.dart';

String? _extraString(Map map, String key) {
  final v = map[key];
  return v is String ? v : null;
}

int? _extraInt(Map map, String key) {
  final v = map[key];
  return v is int ? v : null;
}

GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: '/book/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return BookFolderPage(bookId: id);
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: '/detect-topics',
        builder: (context, state) {
          final map = state.extra is Map ? state.extra as Map : const {};
          return TopicDetectPage(
            bookId: _extraString(map, 'bookId'),
            pdfName: _extraString(map, 'pdfName') ?? 'Untitled.pdf',
            localPath: _extraString(map, 'localPath'),
            coverPath: _extraString(map, 'coverPath'),
          );
        },
      ),
      GoRoute(
        path: '/manual-range',
        builder: (context, state) {
          final map = state.extra is Map ? state.extra as Map : const {};
          return ManualRangePage(
            bookId: _extraString(map, 'bookId'),
            pdfName: _extraString(map, 'pdfName') ?? 'Untitled.pdf',
            localPath: _extraString(map, 'localPath'),
            coverPath: _extraString(map, 'coverPath'),
          );
        },
      ),
      GoRoute(
        path: '/chapters-empty',
        builder: (context, state) {
          final map = state.extra is Map ? state.extra as Map : const {};
          return ChapterEmptyPage(
            bookId: _extraString(map, 'bookId'),
            pdfName: _extraString(map, 'pdfName') ?? 'Untitled.pdf',
            localPath: _extraString(map, 'localPath'),
            coverPath: _extraString(map, 'coverPath'),
          );
        },
      ),
      GoRoute(
        path: '/chapters-found',
        builder: (context, state) {
          final map = state.extra is Map ? state.extra as Map : const {};
          final chaptersRaw = map['chapters'];
          final chapters = chaptersRaw is List
              ? chaptersRaw.whereType<DetectedChapter>().toList()
              : const <DetectedChapter>[];
          return ChapterFoundPage(
            bookId: _extraString(map, 'bookId'),
            pdfName: _extraString(map, 'pdfName') ?? 'Untitled.pdf',
            localPath: _extraString(map, 'localPath'),
            coverPath: _extraString(map, 'coverPath'),
            chapters: chapters,
            windowFrom: _extraInt(map, 'windowFrom'),
            windowTo: _extraInt(map, 'windowTo'),
            notes: _extraString(map, 'notes'),
          );
        },
      ),
      GoRoute(
        path: '/reader/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final map = state.extra is Map ? state.extra as Map : const {};
          final tab = _extraString(map, 'tab');
          final page = _extraInt(map, 'page');
          return ReaderPage(
            sessionId: id,
            initialTab: tab == 'summary' ? 'summary' : 'pdf',
            initialPage: page,
          );
        },
      ),
    ],
  );
}
