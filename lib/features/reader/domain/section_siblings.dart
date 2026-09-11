import 'package:folio/features/sessions/domain/reading_session.dart';

/// Ordered siblings within a book for PDF section handoff.
abstract final class SectionSiblings {
  static List<ReadingSession> orderedForBook(
    List<ReadingSession> all,
    String? bookId,
  ) {
    if (bookId == null || bookId.isEmpty) return const [];
    return all.where((s) => s.bookId == bookId).toList()
      ..sort((a, b) {
        final byFrom = a.fromPage.compareTo(b.fromPage);
        if (byFrom != 0) return byFrom;
        return a.id.compareTo(b.id);
      });
  }

  static int indexOf(List<ReadingSession> ordered, String sessionId) {
    return ordered.indexWhere((s) => s.id == sessionId);
  }

  static ReadingSession? next(
    List<ReadingSession> ordered,
    String sessionId,
  ) {
    final i = indexOf(ordered, sessionId);
    if (i < 0 || i + 1 >= ordered.length) return null;
    return ordered[i + 1];
  }

  static ReadingSession? previous(
    List<ReadingSession> ordered,
    String sessionId,
  ) {
    final i = indexOf(ordered, sessionId);
    if (i <= 0) return null;
    return ordered[i - 1];
  }

  /// Section whose inclusive page range contains [page], or the nearest
  /// preceding section if [page] falls in a gap / past the last end.
  static ReadingSession? atPage(List<ReadingSession> ordered, int page) {
    if (ordered.isEmpty || page < 1) return null;
    ReadingSession? preceding;
    for (final s in ordered) {
      if (page >= s.fromPage && page <= s.toPage) return s;
      if (s.fromPage <= page) preceding = s;
    }
    return preceding ?? ordered.first;
  }
}
