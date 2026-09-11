import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:folio/features/ai/data/local_gemma_service.dart';

class SummarizeJobState {
  const SummarizeJobState({
    required this.sessionId,
    required this.etaSeconds,
    required this.startedAt,
    this.cancelRequested = false,
  });

  final String sessionId;
  final int etaSeconds;
  final DateTime startedAt;
  final bool cancelRequested;

  SummarizeJobState copyWith({
    String? sessionId,
    int? etaSeconds,
    DateTime? startedAt,
    bool? cancelRequested,
  }) {
    return SummarizeJobState(
      sessionId: sessionId ?? this.sessionId,
      etaSeconds: etaSeconds ?? this.etaSeconds,
      startedAt: startedAt ?? this.startedAt,
      cancelRequested: cancelRequested ?? this.cancelRequested,
    );
  }
}

/// App-wide single-flight summarization lock + ETA metadata.
class SummarizeJobCubit extends Cubit<SummarizeJobState?> {
  SummarizeJobCubit() : super(null);

  bool get isBusy => state != null;

  bool get isCancelRequested => state?.cancelRequested ?? false;

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

  /// Cooperative cancel + interrupt active on-device generation / download.
  void requestCancel() {
    final current = state;
    if (current == null || current.cancelRequested) return;
    emit(current.copyWith(cancelRequested: true));
    LocalGemmaService.instance.cancelDownload();
    unawaited(LocalGemmaService.instance.cancelGeneration());
  }

  void end() {
    emit(null);
  }
}
