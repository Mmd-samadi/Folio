import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexus_chat/features/sessions/domain/reading_session.dart';

class SessionsCubit extends Cubit<List<ReadingSession>> {
  SessionsCubit({List<ReadingSession>? seed})
      : super(seed ?? List<ReadingSession>.from(_demoSessions));

  void rename(String id, String title) {
    emit([
      for (final s in state)
        if (s.id == id) s.copyWith(title: title.trim()) else s,
    ]);
  }

  void delete(String id) {
    emit(state.where((s) => s.id != id).toList());
  }

  void add(ReadingSession session) {
    emit([session, ...state]);
  }

  void clearAll() => emit(const []);

  void loadDemo() => emit(List<ReadingSession>.from(_demoSessions));
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
