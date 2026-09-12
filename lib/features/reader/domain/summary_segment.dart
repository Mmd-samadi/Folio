/// One archived generation of a [SummarySegment].
class SummaryRevision {
  const SummaryRevision({
    required this.bullets,
    required this.createdAt,
  });

  final List<String> bullets;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'bullets': bullets,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SummaryRevision.fromJson(Map<String, dynamic> json) {
    final bulletsRaw = json['bullets'];
    final bullets = bulletsRaw is List
        ? bulletsRaw
            .map((e) => e.toString())
            .where((s) => s.trim().isNotEmpty)
            .toList()
        : <String>[];
    return SummaryRevision(
      bullets: bullets,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

/// One AI summary for a contiguous PDF page range within a book.
class SummarySegment {
  const SummarySegment({
    required this.id,
    required this.fromPage,
    required this.toPage,
    required this.bullets,
    required this.createdAt,
    required this.updatedAt,
    this.previousVersions = const [],
  });

  final String id;
  final int fromPage;
  final int toPage;
  final List<String> bullets;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<SummaryRevision> previousVersions;

  String get pageRangeLabel => 'Pages $fromPage–$toPage';

  bool get hasContent => bullets.isNotEmpty;

  SummarySegment copyWith({
    String? id,
    int? fromPage,
    int? toPage,
    List<String>? bullets,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<SummaryRevision>? previousVersions,
  }) {
    return SummarySegment(
      id: id ?? this.id,
      fromPage: fromPage ?? this.fromPage,
      toPage: toPage ?? this.toPage,
      bullets: bullets ?? this.bullets,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      previousVersions: previousVersions ?? this.previousVersions,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fromPage': fromPage,
        'toPage': toPage,
        'bullets': bullets,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'previousVersions': [
          for (final v in previousVersions) v.toJson(),
        ],
      };

  factory SummarySegment.fromJson(Map<String, dynamic> json) {
    final bulletsRaw = json['bullets'];
    final bullets = bulletsRaw is List
        ? bulletsRaw.map((e) => e.toString()).where((s) => s.trim().isNotEmpty).toList()
        : <String>[];
    final prevRaw = json['previousVersions'];
    final previous = <SummaryRevision>[];
    if (prevRaw is List) {
      for (final item in prevRaw) {
        if (item is Map<String, dynamic>) {
          previous.add(SummaryRevision.fromJson(item));
        } else if (item is Map) {
          previous.add(
            SummaryRevision.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    return SummarySegment(
      id: json['id'] as String? ?? '',
      fromPage: json['fromPage'] as int? ?? 1,
      toPage: json['toPage'] as int? ?? 1,
      bullets: bullets,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      previousVersions: previous,
    );
  }
}
