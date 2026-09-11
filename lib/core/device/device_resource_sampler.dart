import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Snapshot of app + device memory pressure.
class DeviceResourceSample {
  const DeviceResourceSample({
    required this.appRssBytes,
    this.deviceAvailBytes,
    this.deviceTotalBytes,
  });

  final int appRssBytes;
  final int? deviceAvailBytes;
  final int? deviceTotalBytes;

  double? get deviceUsedFraction {
    final total = deviceTotalBytes;
    final avail = deviceAvailBytes;
    if (total == null || avail == null || total <= 0) return null;
    return ((total - avail) / total).clamp(0.0, 1.0);
  }

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(0)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(mb >= 100 ? 0 : 1)} MB';
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(2)} GB';
  }
}

/// Reads process RSS (Dart) and optional system RAM via Android MethodChannel.
class DeviceResourceSampler {
  DeviceResourceSampler({
    MethodChannel? channel,
  }) : _channel = channel ??
            const MethodChannel('app.folio.reader/device_resources');

  final MethodChannel _channel;

  Future<DeviceResourceSample> sample() async {
    final rss = ProcessInfo.currentRss;
    if (kIsWeb || !Platform.isAndroid) {
      return DeviceResourceSample(appRssBytes: rss);
    }

    try {
      final raw =
          await _channel.invokeMethod<Map<dynamic, dynamic>>('getMemory');
      if (raw == null) {
        return DeviceResourceSample(appRssBytes: rss);
      }
      final avail = (raw['availMem'] as num?)?.toInt();
      final total = (raw['totalMem'] as num?)?.toInt();
      return DeviceResourceSample(
        appRssBytes: rss,
        deviceAvailBytes: avail,
        deviceTotalBytes: total,
      );
    } catch (_) {
      return DeviceResourceSample(appRssBytes: rss);
    }
  }
}
