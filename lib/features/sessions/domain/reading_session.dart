class ReadingSession {
  const ReadingSession({
    required this.id,
    required this.title,
    required this.pdfName,
    required this.fromPage,
    required this.toPage,
    required this.updatedAt,
    this.progress = 0,
    this.localPath,
  });

  final String id;
  final String title;
  final String pdfName;
  final int fromPage;
  final int toPage;
  final DateTime updatedAt;
  final double progress;
  /// Absolute path inside app documents. Null for demo sessions.
  final String? localPath;

  bool get hasLocalPdf => localPath != null && localPath!.isNotEmpty;

  String get pageRangeLabel => 'pp. $fromPage–$toPage';

  String get dateLabel {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final m = months[updatedAt.month - 1];
    final d = updatedAt.day.toString().padLeft(2, '0');
    return '$m $d, ${updatedAt.year}';
  }

  ReadingSession copyWith({
    String? id,
    String? title,
    String? pdfName,
    int? fromPage,
    int? toPage,
    DateTime? updatedAt,
    double? progress,
    String? localPath,
  }) {
    return ReadingSession(
      id: id ?? this.id,
      title: title ?? this.title,
      pdfName: pdfName ?? this.pdfName,
      fromPage: fromPage ?? this.fromPage,
      toPage: toPage ?? this.toPage,
      updatedAt: updatedAt ?? this.updatedAt,
      progress: progress ?? this.progress,
      localPath: localPath ?? this.localPath,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'pdfName': pdfName,
        'fromPage': fromPage,
        'toPage': toPage,
        'updatedAt': updatedAt.toIso8601String(),
        'progress': progress,
        'localPath': localPath,
      };

  factory ReadingSession.fromJson(Map<String, dynamic> json) {
    return ReadingSession(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled',
      pdfName: json['pdfName'] as String? ?? 'file.pdf',
      fromPage: json['fromPage'] as int? ?? 1,
      toPage: json['toPage'] as int? ?? 1,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      localPath: json['localPath'] as String?,
    );
  }
}

class DetectedChapter {
  const DetectedChapter({
    required this.title,
    required this.fromPage,
    required this.toPage,
    this.selected = true,
  });

  final String title;
  final int fromPage;
  final int toPage;
  final bool selected;

  DetectedChapter copyWith({bool? selected}) {
    return DetectedChapter(
      title: title,
      fromPage: fromPage,
      toPage: toPage,
      selected: selected ?? this.selected,
    );
  }
}

class PageRangeDraft {
  const PageRangeDraft({
    required this.fromPage,
    required this.toPage,
    this.title = '',
  });

  final int fromPage;
  final int toPage;
  final String title;

  int get totalPages =>
      (toPage >= fromPage && fromPage > 0) ? (toPage - fromPage + 1) : 0;
}
