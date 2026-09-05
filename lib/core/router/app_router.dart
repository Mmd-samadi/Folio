import 'package:go_router/go_router.dart';
import 'package:nexus_chat/features/import/presentation/pages/chapter_detection_page.dart';
import 'package:nexus_chat/features/import/presentation/pages/manual_range_page.dart';
import 'package:nexus_chat/features/reader/presentation/pages/reader_page.dart';
import 'package:nexus_chat/features/sessions/domain/reading_session.dart';
import 'package:nexus_chat/features/sessions/presentation/pages/home_page.dart';
import 'package:nexus_chat/features/sessions/presentation/pages/splash_page.dart';
import 'package:nexus_chat/features/settings/presentation/pages/settings_page.dart';

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
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: '/manual-range',
        builder: (context, state) {
          final extra = state.extra;
          final map = extra is Map ? extra : const {};
          return ManualRangePage(
            pdfName: map['pdfName'] is String
                ? map['pdfName'] as String
                : 'Untitled.pdf',
            localPath:
                map['localPath'] is String ? map['localPath'] as String : null,
          );
        },
      ),
      GoRoute(
        path: '/chapters-empty',
        builder: (context, state) {
          final map = state.extra is Map ? state.extra as Map : const {};
          return ChapterEmptyPage(
            pdfName: map['pdfName'] is String
                ? map['pdfName'] as String
                : 'Untitled.pdf',
            localPath:
                map['localPath'] is String ? map['localPath'] as String : null,
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
            pdfName: map['pdfName'] is String
                ? map['pdfName'] as String
                : 'Untitled.pdf',
            localPath:
                map['localPath'] is String ? map['localPath'] as String : null,
            chapters: chapters,
          );
        },
      ),
      GoRoute(
        path: '/reader/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ReaderPage(sessionId: id);
        },
      ),
    ],
  );
}
