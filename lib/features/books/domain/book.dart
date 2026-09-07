/// One imported PDF, containing one or more Folio parts ([ReadingSession]s).
class Book {
  const Book({
    required this.id,
    required this.title,
    required this.pdfName,
    required this.sourcePdfPath,
    required this.createdAt,
    required this.updatedAt,
    this.coverPath,
  });

  final String id;
  final String title;
  final String pdfName;
  final String sourcePdfPath;
  final String? coverPath;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasCover => coverPath != null && coverPath!.isNotEmpty;

  Book copyWith({
    String? id,
    String? title,
    String? pdfName,
    String? sourcePdfPath,
    String? coverPath,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearCover = false,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      pdfName: pdfName ?? this.pdfName,
      sourcePdfPath: sourcePdfPath ?? this.sourcePdfPath,
      coverPath: clearCover ? null : (coverPath ?? this.coverPath),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'pdfName': pdfName,
        'sourcePdfPath': sourcePdfPath,
        'coverPath': coverPath,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled',
      pdfName: json['pdfName'] as String? ?? 'file.pdf',
      sourcePdfPath: json['sourcePdfPath'] as String? ?? '',
      coverPath: json['coverPath'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  /// Display title derived from a PDF file name (strips `.pdf`, softens `_`).
  static String titleFromPdfName(String pdfName) {
    var name = pdfName.trim();
    if (name.toLowerCase().endsWith('.pdf')) {
      name = name.substring(0, name.length - 4);
    }
    name = name.replaceAll('_', ' ').trim();
    return name.isEmpty ? 'Untitled' : name;
  }
}
