import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:folio/core/device/device_resource_sampler.dart';

enum OnDeviceLoadKind { download, infer }

class OnDeviceLoadState {
  const OnDeviceLoadState({
    required this.kind,
    required this.sample,
    this.downloadProgress,
  });

  final OnDeviceLoadKind kind;
  final DeviceResourceSample sample;
  final int? downloadProgress;

  String get statusLabel => switch (kind) {
        OnDeviceLoadKind.download => 'Downloading model…',
        OnDeviceLoadKind.infer => 'Running on-device AI…',
      };
}

/// Tracks on-device work and polls memory while busy.
class OnDeviceLoadCubit extends Cubit<OnDeviceLoadState?> {
  OnDeviceLoadCubit({DeviceResourceSampler? sampler})
      : _sampler = sampler ?? DeviceResourceSampler(),
        super(null);

  final DeviceResourceSampler _sampler;
  Timer? _timer;
  OnDeviceLoadKind? _kind;
  int? _downloadProgress;

  bool get isBusy => state != null;

  Future<void> begin(OnDeviceLoadKind kind, {int? downloadProgress}) async {
    _kind = kind;
    _downloadProgress = downloadProgress;
    await _emitSample();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_emitSample());
    });
  }

  void updateDownloadProgress(int progress) {
    _downloadProgress = progress;
    final current = state;
    if (current == null) return;
    emit(
      OnDeviceLoadState(
        kind: current.kind,
        sample: current.sample,
        downloadProgress: progress,
      ),
    );
  }

  Future<void> end() async {
    _timer?.cancel();
    _timer = null;
    _kind = null;
    _downloadProgress = null;
    emit(null);
  }

  Future<void> _emitSample() async {
    final kind = _kind;
    if (kind == null) return;
    final sample = await _sampler.sample();
    if (_kind == null) return;
    emit(
      OnDeviceLoadState(
        kind: kind,
        sample: sample,
        downloadProgress: _downloadProgress,
      ),
    );
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
