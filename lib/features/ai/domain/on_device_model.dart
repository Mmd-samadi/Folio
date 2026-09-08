import 'package:flutter_gemma/flutter_gemma.dart';

/// Spec for a downloadable on-device inference model.
class OnDeviceModel {
  const OnDeviceModel({
    required this.id,
    required this.label,
    required this.sizeLabel,
    required this.fileName,
    required this.url,
    required this.modelType,
    required this.fileType,
    this.description = '',
    this.needsAuth = false,
  });

  final String id;
  final String label;
  final String sizeLabel;
  final String fileName;
  final String url;
  final ModelType modelType;
  final ModelFileType fileType;
  final String description;
  final bool needsAuth;

  factory OnDeviceModel.fromJson(Map<String, dynamic> json) {
    final modelType = _parseModelType(json['modelType'] as String?);
    final fileType = _parseFileType(json['fileType'] as String?);
    if (modelType == null || fileType == null) {
      throw FormatException(
        'Unknown modelType/fileType for model ${json['id']}',
      );
    }

    final id = (json['id'] as String?)?.trim() ?? '';
    final label = (json['label'] as String?)?.trim() ?? '';
    final fileName = (json['fileName'] as String?)?.trim() ?? '';
    final url = (json['url'] as String?)?.trim() ?? '';
    if (id.isEmpty || label.isEmpty || fileName.isEmpty || url.isEmpty) {
      throw const FormatException('Model missing required fields');
    }

    return OnDeviceModel(
      id: id,
      label: label,
      sizeLabel: (json['sizeLabel'] as String?)?.trim() ?? '',
      fileName: fileName,
      url: url,
      modelType: modelType,
      fileType: fileType,
      description: (json['description'] as String?)?.trim() ?? '',
      needsAuth: json['needsAuth'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'sizeLabel': sizeLabel,
        'fileName': fileName,
        'url': url,
        'modelType': modelType.name,
        'fileType': fileType.name,
        'description': description,
        'needsAuth': needsAuth,
      };

  static ModelType? _parseModelType(String? raw) {
    switch ((raw ?? '').trim()) {
      case 'general':
        return ModelType.general;
      case 'gemmaIt':
        return ModelType.gemmaIt;
      case 'gemma4':
        return ModelType.gemma4;
      case 'deepSeek':
        return ModelType.deepSeek;
      case 'qwen':
        return ModelType.qwen;
      case 'qwen3':
        return ModelType.qwen3;
      case 'llama':
        return ModelType.llama;
      case 'hammer':
        return ModelType.hammer;
      case 'functionGemma':
        return ModelType.functionGemma;
      case 'phi':
        return ModelType.phi;
      default:
        return null;
    }
  }

  static ModelFileType? _parseFileType(String? raw) {
    switch ((raw ?? '').trim()) {
      case 'task':
        return ModelFileType.task;
      case 'binary':
        return ModelFileType.binary;
      case 'litertlm':
        return ModelFileType.litertlm;
      case 'builtIn':
        return ModelFileType.builtIn;
      case 'onnx':
        return ModelFileType.onnx;
      default:
        return null;
    }
  }
}

/// Snapshot of the on-device model catalog (from JSON asset, cache, or remote).
class OnDeviceCatalogSnapshot {
  const OnDeviceCatalogSnapshot({
    required this.version,
    required this.defaultId,
    required this.models,
    required this.source,
    this.fetchedAt,
  });

  final int version;
  final String defaultId;
  final List<OnDeviceModel> models;
  final OnDeviceCatalogSource source;
  final DateTime? fetchedAt;

  OnDeviceModel get defaultModel => byId(defaultId);

  OnDeviceModel byId(String? id) {
    final key = (id ?? '').trim();
    if (key.isEmpty) return models.first;
    for (final model in models) {
      if (model.id == key) return model;
    }
    return models.first;
  }
}

enum OnDeviceCatalogSource { bundled, cache, remote }

/// Runtime facade over [OnDeviceModelCatalogService]'s latest snapshot.
abstract final class OnDeviceModels {
  static const fallbackDefaultId = 'qwen3-0.6b';

  static OnDeviceCatalogSnapshot? _snapshot;

  static void apply(OnDeviceCatalogSnapshot snapshot) {
    if (snapshot.models.isEmpty) return;
    _snapshot = snapshot;
  }

  static OnDeviceCatalogSnapshot? get snapshot => _snapshot;

  static List<OnDeviceModel> get catalog =>
      List.unmodifiable(_snapshot?.models ?? const <OnDeviceModel>[]);

  static String get defaultId =>
      _snapshot?.defaultId ?? fallbackDefaultId;

  static OnDeviceModel get defaultModel {
    final snap = _snapshot;
    if (snap == null || snap.models.isEmpty) {
      throw StateError(
        'On-device model catalog is not loaded yet. Call '
        'OnDeviceModelCatalogService.instance.ensureLoaded() first.',
      );
    }
    return snap.defaultModel;
  }

  static OnDeviceModel byId(String? id) {
    final snap = _snapshot;
    if (snap == null || snap.models.isEmpty) {
      throw StateError(
        'On-device model catalog is not loaded yet. Call '
        'OnDeviceModelCatalogService.instance.ensureLoaded() first.',
      );
    }
    return snap.byId(id);
  }
}
