import 'dart:convert';

import 'package:nexus_chat/features/books/domain/book.dart';
import 'package:nexus_chat/features/sessions/domain/reading_session.dart';
import 'package:nexus_chat/features/settings/domain/folio_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStore {
  LocalStore(this._prefs);

  final SharedPreferences _prefs;

  static const _sessionsKey = 'folio_sessions_v1';
  static const _booksKey = 'folio_books_v1';
  static const _settingsKey = 'folio_settings_v1';
  static const _annotationsKey = 'folio_annotations_v1';

  static Future<LocalStore> open() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalStore(prefs);
  }

  List<ReadingSession> loadSessions() {
    final raw = _prefs.getString(_sessionsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map>()
          .map((e) => ReadingSession.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveSessions(List<ReadingSession> sessions) async {
    final encoded = jsonEncode(sessions.map((s) => s.toJson()).toList());
    await _prefs.setString(_sessionsKey, encoded);
  }

  List<Book> loadBooks() {
    final raw = _prefs.getString(_booksKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map>()
          .map((e) => Book.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveBooks(List<Book> books) async {
    final encoded = jsonEncode(books.map((b) => b.toJson()).toList());
    await _prefs.setString(_booksKey, encoded);
  }

  FolioSettings loadSettings() {
    final raw = _prefs.getString(_settingsKey);
    if (raw == null || raw.isEmpty) return const FolioSettings();
    try {
      return FolioSettings.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return const FolioSettings();
    }
  }

  Future<void> saveSettings(FolioSettings settings) async {
    await _prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  List<SessionAnnotation> loadAnnotations(String sessionId) {
    final all = _loadAllAnnotations();
    return all[sessionId] ?? const [];
  }

  Future<void> addAnnotation(SessionAnnotation annotation) async {
    final all = _loadAllAnnotations();
    final list = <SessionAnnotation>[
      ...(all[annotation.sessionId] ?? const <SessionAnnotation>[]),
      annotation,
    ];
    all[annotation.sessionId] = list;
    await _prefs.setString(
      _annotationsKey,
      jsonEncode(
        all.map((k, v) => MapEntry(k, v.map((a) => a.toJson()).toList())),
      ),
    );
  }

  Map<String, List<SessionAnnotation>> _loadAllAnnotations() {
    final raw = _prefs.getString(_annotationsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((key, value) {
        final list = (value as List<dynamic>)
            .whereType<Map>()
            .map((e) => SessionAnnotation.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        return MapEntry(key, list);
      });
    } catch (_) {
      return {};
    }
  }
}

class SessionAnnotation {
  const SessionAnnotation({
    required this.sessionId,
    required this.quote,
    required this.note,
    required this.createdAt,
  });

  final String sessionId;
  final String quote;
  final String note;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'quote': quote,
        'note': note,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SessionAnnotation.fromJson(Map<String, dynamic> json) {
    return SessionAnnotation(
      sessionId: json['sessionId'] as String? ?? '',
      quote: json['quote'] as String? ?? '',
      note: json['note'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
