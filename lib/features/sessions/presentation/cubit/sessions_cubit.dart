import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexus_chat/core/storage/local_store.dart';
import 'package:nexus_chat/features/sessions/domain/reading_session.dart';

class SessionsCubit extends Cubit<List<ReadingSession>> {
  SessionsCubit({
    required LocalStore store,
    List<ReadingSession>? seed,
  }) : super(seed ?? const []) {
    _store = store;
  }

  late final LocalStore _store;

  Future<void> hydrate() async {
    final saved = _store.loadSessions();
    // Drop legacy demo sessions that never had a local PDF file.
    final real = saved.where((s) => s.hasLocalPdf).toList();
    if (real.length != saved.length) {
      emit(real);
      await _persist();
      return;
    }
    emit(saved);
  }

  Future<void> rename(String id, String title) async {
    emit([
      for (final s in state)
        if (s.id == id) s.copyWith(title: title.trim()) else s,
    ]);
    await _persist();
  }

  Future<void> delete(String id) async {
    emit(state.where((s) => s.id != id).toList());
    await _persist();
  }

  Future<void> add(ReadingSession session) async {
    emit([session, ...state]);
    await _persist();
  }

  Future<void> addAll(List<ReadingSession> sessions) async {
    if (sessions.isEmpty) return;
    emit([...sessions, ...state]);
    await _persist();
  }

  Future<void> replaceAll(List<ReadingSession> sessions) async {
    emit(List.of(sessions));
    await _persist();
  }

  Future<void> deleteByBookId(String bookId) async {
    emit(state.where((s) => s.bookId != bookId).toList());
    await _persist();
  }

  Future<void> updateProgress(String id, double progress) async {
    emit([
      for (final s in state)
        if (s.id == id)
          s.copyWith(progress: progress.clamp(0.0, 1.0), updatedAt: DateTime.now())
        else
          s,
    ]);
    await _persist();
  }

  Future<void> saveSummary(String id, List<String> bullets) async {
    final cleaned = bullets.map((b) => b.trim()).where((b) => b.isNotEmpty).toList();
    emit([
      for (final s in state)
        if (s.id == id)
          s.copyWith(
            summaryBullets: cleaned,
            summaryUpdatedAt: DateTime.now(),
            updatedAt: DateTime.now(),
          )
        else
          s,
    ]);
    await _persist();
  }

  Future<void> clearSummary(String id) async {
    emit([
      for (final s in state)
        if (s.id == id) s.copyWith(clearSummary: true) else s,
    ]);
    await _persist();
  }

  Future<void> clearAll() async {
    emit(const []);
    await _persist();
  }

  Future<void> _persist() => _store.saveSessions(state);
}
