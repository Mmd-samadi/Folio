import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:nexus_chat/core/constants/app_constants.dart';
import 'package:nexus_chat/features/ai/domain/on_device_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Loads the on-device model list from remote JSON, disk cache, or bundled asset.
///
/// Remote URL (optional):
/// - `--dart-define=ON_DEVICE_MODELS_CATALOG_URL=...`
/// - or `.env` key `ON_DEVICE_MODELS_CATALOG_URL`
///
/// When the URL is set, Folio refreshes at most once per [cacheTtl].
class OnDeviceModelCatalogService {
  OnDeviceModelCatalogService._();

  static final OnDeviceModelCatalogService instance =
      OnDeviceModelCatalogService._();

  static const cacheTtl = Duration(hours: 24);
  static const _cacheJsonKey = 'folio_on_device_catalog_json_v1';
  static const _cacheFetchedAtKey = 'folio_on_device_catalog_fetched_at_v1';
  static const bundledAssetPath = 'assets/on_device_models.json';

  bool _loading = false;

  Future<OnDeviceCatalogSnapshot> ensureLoaded({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        OnDeviceModels.snapshot != null &&
        OnDeviceModels.catalog.isNotEmpty) {
      return OnDeviceModels.snapshot!;
    }
    while (_loading) {
      await Future<void>.delayed(const Duration(milliseconds: 40));
      if (!forceRefresh && OnDeviceModels.snapshot != null) {
        return OnDeviceModels.snapshot!;
      }
    }
    _loading = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final remoteUrl = _resolveRemoteUrl();

      if (!forceRefresh) {
        final cached = _readCache(prefs);
        if (cached != null && !_isStale(cached.fetchedAt)) {
          OnDeviceModels.apply(cached);
          // Refresh in background when a remote URL is configured.
          if (remoteUrl != null) {
            // ignore: unawaited_futures
            _tryFetchAndCache(remoteUrl, prefs);
          }
          return cached;
        }
      }

      if (remoteUrl != null) {
        final remote = await _tryFetchAndCache(remoteUrl, prefs);
        if (remote != null) return remote;
      }

      final cached = _readCache(prefs);
      if (cached != null) {
        OnDeviceModels.apply(cached);
        return cached;
      }

      final bundled = await _loadBundled();
      OnDeviceModels.apply(bundled);
      return bundled;
    } finally {
      _loading = false;
    }
  }

  Future<OnDeviceCatalogSnapshot> refresh() =>
      ensureLoaded(forceRefresh: true);

  String? _resolveRemoteUrl() {
    const fromDefine = String.fromEnvironment(
      AppConstants.onDeviceModelsCatalogUrlDefine,
    );
    if (fromDefine.trim().isNotEmpty) return fromDefine.trim();

    final fromEnv =
        dotenv.env[AppConstants.onDeviceModelsCatalogUrlEnv]?.trim() ?? '';
    if (fromEnv.isNotEmpty) return fromEnv;

    final fallback = AppConstants.onDeviceModelsCatalogUrl.trim();
    return fallback.isEmpty ? null : fallback;
  }

  bool _isStale(DateTime? fetchedAt) {
    if (fetchedAt == null) return true;
    return DateTime.now().difference(fetchedAt) > cacheTtl;
  }

  OnDeviceCatalogSnapshot? _readCache(SharedPreferences prefs) {
    final raw = prefs.getString(_cacheJsonKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final fetchedMs = prefs.getInt(_cacheFetchedAtKey);
      final fetchedAt = fetchedMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(fetchedMs);
      return _parse(
        raw,
        source: OnDeviceCatalogSource.cache,
        fetchedAt: fetchedAt,
      );
    } catch (_) {
      return null;
    }
  }

  Future<OnDeviceCatalogSnapshot?> _tryFetchAndCache(
    String url,
    SharedPreferences prefs,
  ) async {
    try {
      final body = await _httpGet(url);
      final snapshot = _parse(
        body,
        source: OnDeviceCatalogSource.remote,
        fetchedAt: DateTime.now(),
      );
      await prefs.setString(_cacheJsonKey, body);
      await prefs.setInt(
        _cacheFetchedAtKey,
        snapshot.fetchedAt!.millisecondsSinceEpoch,
      );
      OnDeviceModels.apply(snapshot);
      return snapshot;
    } catch (_) {
      return null;
    }
  }

  Future<String> _httpGet(String url) async {
    final client = HttpClient();
    try {
      final request = await client
          .getUrl(Uri.parse(url))
          .timeout(const Duration(seconds: 12));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response =
          await request.close().timeout(const Duration(seconds: 20));
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Catalog HTTP ${response.statusCode}',
          uri: Uri.parse(url),
        );
      }
      return body;
    } finally {
      client.close(force: true);
    }
  }

  Future<OnDeviceCatalogSnapshot> _loadBundled() async {
    final raw = await rootBundle.loadString(bundledAssetPath);
    return _parse(
      raw,
      source: OnDeviceCatalogSource.bundled,
      fetchedAt: null,
    );
  }

  OnDeviceCatalogSnapshot _parse(
    String raw, {
    required OnDeviceCatalogSource source,
    required DateTime? fetchedAt,
  }) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Catalog root must be an object');
    }
    final map = Map<String, dynamic>.from(decoded);
    final modelsRaw = map['models'];
    if (modelsRaw is! List) {
      throw const FormatException('Catalog models must be a list');
    }

    final models = <OnDeviceModel>[];
    for (final item in modelsRaw) {
      if (item is! Map) continue;
      try {
        final model = OnDeviceModel.fromJson(Map<String, dynamic>.from(item));
        if (model.needsAuth) continue;
        models.add(model);
      } catch (_) {
        // Skip unknown / invalid entries so one bad row cannot break the app.
      }
    }
    if (models.isEmpty) {
      throw const FormatException('Catalog contained no usable models');
    }

    final defaultId = (map['defaultId'] as String?)?.trim();
    final resolvedDefault = (defaultId != null &&
            models.any((m) => m.id == defaultId))
        ? defaultId
        : models.first.id;

    final version = switch (map['version']) {
      final int v => v,
      final num v => v.toInt(),
      final String v => int.tryParse(v) ?? 1,
      _ => 1,
    };

    return OnDeviceCatalogSnapshot(
      version: version,
      defaultId: resolvedDefault,
      models: models,
      source: source,
      fetchedAt: fetchedAt,
    );
  }
}
