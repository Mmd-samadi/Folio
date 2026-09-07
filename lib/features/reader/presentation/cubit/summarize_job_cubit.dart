import 'package:flutter_bloc/flutter_bloc.dart';

class SummarizeJobState {
  const SummarizeJobState({
    required this.sessionId,
    required this.etaSeconds,
    required this.startedAt,
  });

  final String sessionId;
  final int etaSeconds;
  final DateTime startedAt;
}

/// App-wide single-flight summarization lock + ETA metadata.
class SummarizeJobCubit extends Cubit<SummarizeJobState?> {
  SummarizeJobCubit() : super(null);

  bool get isBusy => state != null;

  /// Returns false if another job is already running.
  bool tryBegin({required String sessionId, required int etaSeconds}) {
    if (state != null) return false;
    emit(
      SummarizeJobState(
        sessionId: sessionId,
        etaSeconds: etaSeconds,
        startedAt: DateTime.now(),
      ),
    );
    return true;
  }

  void end() => emit(null);
}
