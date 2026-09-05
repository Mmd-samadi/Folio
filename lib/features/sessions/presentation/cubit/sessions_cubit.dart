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
    if (saved.isNotEmpty) {
      emit(saved);
      return;
    }

    if (!_store.demoSeeded) {
      emit(List<ReadingSession>.from(_demoSessions));
      await _persist();
      await _store.markDemoSeeded();
    } else {
      emit(const []);
    }
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

  Future<void> clearAll() async {
    emit(const []);
    await _persist();
  }

  Future<void> _persist() => _store.saveSessions(state);
}

final _demoSessions = [
  ReadingSession(
    id: '1',
    title: 'Transformer Architectures',
    pdfName: 'Attention_Is_All_You_Need.pdf',
    fromPage: 12,
    toPage: 45,
    updatedAt: DateTime(2024, 5, 14),
    progress: 0.62,
  ),
  ReadingSession(
    id: '2',
    title: 'Convolutional Networks',
    pdfName: 'Deep_Learning_Book.pdf',
    fromPage: 320,
    toPage: 380,
    updatedAt: DateTime(2024, 5, 12),
    progress: 0.28,
  ),
  ReadingSession(
    id: '3',
    title: 'Contrastive Learning',
    pdfName: 'SimCLR_V2_Review.pdf',
    fromPage: 1,
    toPage: 8,
    updatedAt: DateTime(2024, 5, 8),
    progress: 0.9,
  ),
];
