import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:folio/core/storage/local_store.dart';
import 'package:folio/core/errors/cancelled_exception.dart';
import 'package:folio/core/theme/folio_colors.dart';
import 'package:folio/core/widgets/folio_buttons.dart';
import 'package:folio/core/widgets/folio_feedback.dart';
import 'package:folio/features/books/domain/book.dart';
import 'package:folio/features/books/presentation/cubit/books_cubit.dart';
import 'package:folio/features/chat/data/api_exception.dart';
import 'package:folio/features/chat/data/network_exception.dart';
import 'package:folio/features/reader/data/folio_ai_service.dart';
import 'package:folio/features/reader/data/section_summarizer.dart';
import 'package:folio/features/reader/domain/section_page_range.dart';
import 'package:folio/features/reader/domain/section_siblings.dart';
import 'package:folio/features/reader/domain/summarize_eta.dart';
import 'package:folio/features/reader/domain/summary_segment.dart';
import 'package:folio/features/reader/presentation/cubit/summarize_job_cubit.dart';
import 'package:folio/features/ai/data/local_gemma_service.dart';
import 'package:folio/features/ai/domain/folio_ai_provider.dart';
import 'package:folio/features/ai/domain/on_device_model.dart';
import 'package:folio/features/reader/presentation/widgets/reader_sheets.dart';
import 'package:folio/features/sessions/domain/reading_session.dart';
import 'package:folio/features/sessions/presentation/cubit/sessions_cubit.dart';
import 'package:folio/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:folio/features/settings/presentation/widgets/api_key_gate_sheet.dart';
import 'package:pdfrx/pdfrx.dart';

Uint8List _readPdfBytesIsolate(String path) => File(path).readAsBytesSync();

class ReaderPage extends StatefulWidget {
  const ReaderPage({
    super.key,
    required this.sessionId,
    this.initialTab = 'pdf',
    this.initialPage,
  });

  final String sessionId;
  /// `pdf` or `summary`
  final String initialTab;
  /// Optional absolute PDF page to open (e.g. previous section's last page).
  final int? initialPage;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  late _ReaderTab _tab;
  var _format = 'Bullet';
  var _length = 'Medium';
  var _chatExpanded = false;
  var _prompt = FolioAiService.defaultPrompt;
  var _loadingSummary = false;
  var _loadingChat = false;
  String? _summaryError;
  String? _chatError;
  String? _pendingChat;
  Uint8List? _pdfBytes;
  final _chatController = TextEditingController();
  final _messages = <_ChatLine>[];
  final _pdfController = PdfViewerController();
  var _pageLabel = '– / –';
  var _activeSectionTitle = '';
  var _activeSectionId = '';
  var _currentPdfPage = 0;
  var _documentPageCount = 0;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab == 'summary'
        ? _ReaderTab.summary
        : _ReaderTab.pdf;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = context.read<SettingsCubit>().state;
      setState(() {
        _format = settings.format;
        _length = settings.length;
        if (settings.customPrompt.trim().isNotEmpty) {
          _prompt = settings.customPrompt;
        }
      });
      _bootstrap();
    });
  }

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  ReadingSession? _findSession() {
    final sessions = context.read<SessionsCubit>().state;
    try {
      return sessions.firstWhere((s) => s.id == widget.sessionId);
    } catch (_) {
      return sessions.isNotEmpty ? sessions.first : null;
    }
  }

  Future<void> _bootstrap() async {
    final session = _findSession();
    if (session == null) return;
    // Summaries live on the Book as range segments.
  }

  Future<Uint8List?> _ensurePdfBytes(ReadingSession session) async {
    if (_pdfBytes != null) return _pdfBytes;
    if (!session.hasLocalPdf) return null;
    try {
      final bytes = await compute(_readPdfBytesIsolate, session.localPath!);
      if (!mounted) return bytes;
      setState(() => _pdfBytes = bytes);
      return bytes;
    } catch (_) {
      return null;
    }
  }

  Book? _bookFor(ReadingSession session) {
    final bookId = session.bookId;
    if (bookId == null || bookId.isEmpty) return null;
    return context.read<BooksCubit>().byId(bookId);
  }

  List<String> _allSummaryBullets(Book? book) {
    if (book == null) return const [];
    return [
      for (final segment in book.orderedSummarySegments) ...segment.bullets,
    ];
  }

  /// Flattened book summaries used as Ask Folio context.
  String _summaryContextText(Book? book) {
    if (book == null) return '';
    final buffer = StringBuffer();
    for (final segment in book.orderedSummarySegments) {
      if (!segment.hasContent) continue;
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.writeln('--- ${segment.pageRangeLabel} ---');
      for (final bullet in segment.bullets) {
        buffer.writeln('- $bullet');
      }
    }
    return buffer.toString().trim();
  }

  int _resolvedPageCount(ReadingSession session) {
    if (_documentPageCount > 0) return _documentPageCount;
    if (_pdfController.isReady) {
      final count = _pdfController.pageCount;
      if (count > 0) return count;
    }
    return session.toPage;
  }

  int _resolvedCurrentPage(ReadingSession session) {
    if (_currentPdfPage > 0) return _currentPdfPage;
    if (_pdfController.isReady) {
      return _pdfController.pageNumber ?? session.fromPage;
    }
    return session.fromPage;
  }

  Future<void> _openSummarizeRange(ReadingSession session) async {
    final pageCount = _resolvedPageCount(session);
    final current = _resolvedCurrentPage(session);
    final suggestedTo = pageCount > 0
        ? (current + 4).clamp(current, pageCount)
        : session.toPage;
    final request = await showSummarizeRangeSheet(
      context,
      initialFrom: current.clamp(1, pageCount > 0 ? pageCount : current),
      initialTo: suggestedTo,
      pageCount: pageCount,
    );
    if (request == null || !mounted) return;
    await _summarizeRange(
      session,
      fromPage: request.fromPage,
      toPage: request.toPage,
    );
  }

  Future<void> _summarizeRange(
    ReadingSession session, {
    required int fromPage,
    required int toPage,
    String? existingSegmentId,
  }) async {
    final bookId = session.bookId;
    if (bookId == null || bookId.isEmpty) {
      setState(() {
        _summaryError =
            'This PDF is not linked to a book. Re-import to save range summaries.';
      });
      return;
    }
    if (!session.hasLocalPdf) {
      setState(() => _summaryError = 'No local PDF file found.');
      return;
    }

    final jobCubit = context.read<SummarizeJobCubit>();
    if (jobCubit.isBusy) {
      setState(() => _summaryError = 'Another summary is running');
      return;
    }

    final ready = await ensureFolioAiReady(context);
    if (!mounted) return;
    if (!ready) {
      setState(() {
        _loadingSummary = false;
        _summaryError = folioAiNotReadyMessage(
          context.read<SettingsCubit>().state.aiProvider,
        );
      });
      return;
    }

    var fileSize = 0;
    try {
      fileSize = await File(session.localPath!).length();
    } catch (_) {}
    if (!mounted) {
      jobCubit.end();
      return;
    }
    final eta = SummarizeEta.estimateSeconds(
      fromPage: fromPage,
      toPage: toPage,
      fileSizeBytes: fileSize,
    );
    final started = jobCubit.tryBegin(sessionId: session.id, etaSeconds: eta);
    if (!started) {
      setState(() => _summaryError = 'Another summary is running');
      return;
    }

    setState(() {
      _loadingSummary = true;
      _summaryError = null;
      _tab = _ReaderTab.summary;
    });

    final settings = context.read<SettingsCubit>().state;
    final books = context.read<BooksCubit>();

    try {
      final segment = await const SectionSummarizer().summarizeRange(
        pdfPath: session.localPath!,
        fromPage: fromPage,
        toPage: toPage,
        apiKey: settings.apiKey,
        format: _format,
        length: _length,
        customPrompt: _prompt,
        provider: settings.aiProvider,
        onDeviceModel: settings.onDeviceModel,
        existingId: existingSegmentId,
        isCancelled: () => jobCubit.isCancelRequested,
      );
      if (!mounted) return;

      var toSave = segment;
      final existingId = existingSegmentId?.trim();
      if (existingId != null && existingId.isNotEmpty) {
        SummarySegment? existing;
        final list = books.byId(bookId)?.summarySegments;
        if (list != null) {
          for (final s in list) {
            if (s.id == existingId) {
              existing = s;
              break;
            }
          }
        }
        if (existing != null && existing.bullets.isNotEmpty) {
          toSave = segment.copyWith(
            createdAt: existing.createdAt,
            previousVersions: [
              SummaryRevision(
                bullets: List<String>.from(existing.bullets),
                createdAt: existing.updatedAt,
              ),
              ...existing.previousVersions,
            ],
          );
        }
      }

      await books.upsertSummarySegment(bookId: bookId, segment: toSave);
      if (!mounted) return;
      setState(() {
        _loadingSummary = false;
        _summaryError = null;
      });
    } on CancelledException {
      if (!mounted) return;
      setState(() {
        _loadingSummary = false;
        _summaryError = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Summarization cancelled.')),
      );
    } on NetworkException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingSummary = false;
        _summaryError = e.message;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingSummary = false;
        _summaryError = e.message;
      });
    } on StateError catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingSummary = false;
        _summaryError = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingSummary = false;
        _summaryError = 'Summarization failed. Please try again.';
      });
    } finally {
      jobCubit.end();
    }
  }

  Future<void> _deleteSegment(ReadingSession session, String segmentId) async {
    final bookId = session.bookId;
    if (bookId == null) return;
    await context.read<BooksCubit>().deleteSummarySegment(
          bookId: bookId,
          segmentId: segmentId,
        );
  }

  Future<void> _regenerateSegmentWithPrompt(
    ReadingSession session,
    SummarySegment segment,
  ) async {
    final nextPrompt = await showRegenerateWithPromptSheet(
      context,
      pageRangeLabel: segment.pageRangeLabel,
      currentPrompt: _prompt,
    );
    if (nextPrompt == null || !mounted) return;
    setState(() => _prompt = nextPrompt);
    await context.read<SettingsCubit>().setCustomPrompt(nextPrompt);
    if (!mounted) return;
    await _summarizeRange(
      session,
      fromPage: segment.fromPage,
      toPage: segment.toPage,
      existingSegmentId: segment.id,
    );
  }

  Future<void> _restoreSummaryRevision(
    ReadingSession session,
    SummarySegment segment,
    int revisionIndex,
  ) async {
    final bookId = session.bookId;
    if (bookId == null || bookId.isEmpty) return;
    if (revisionIndex < 0 || revisionIndex >= segment.previousVersions.length) {
      return;
    }
    final chosen = segment.previousVersions[revisionIndex];
    final remaining = [
      for (var i = 0; i < segment.previousVersions.length; i++)
        if (i != revisionIndex) segment.previousVersions[i],
    ];
    final archivedCurrent = segment.bullets.isEmpty
        ? remaining
        : [
            SummaryRevision(
              bullets: List<String>.from(segment.bullets),
              createdAt: segment.updatedAt,
            ),
            ...remaining,
          ];
    final restored = segment.copyWith(
      bullets: List<String>.from(chosen.bullets),
      updatedAt: DateTime.now(),
      previousVersions: archivedCurrent,
    );
    await context.read<BooksCubit>().upsertSummarySegment(
          bookId: bookId,
          segment: restored,
        );
  }

  List<ReadingSession> _bookSiblings(ReadingSession session) {
    return SectionSiblings.orderedForBook(
      context.read<SessionsCubit>().state,
      session.bookId,
    );
  }

  bool _isContinuousBook(ReadingSession session) {
    return _bookSiblings(session).length > 1;
  }

  void _onPdfPrev(ReadingSession session) {
    final continuous = _isContinuousBook(session);
    final lo = continuous ? 1 : session.fromPage;
    final current = _resolvedCurrentPage(session);
    if (current > lo) {
      if (!_pdfController.isReady) return;
      _pdfController.goToPage(pageNumber: current - 1);
      return;
    }
    if (!continuous) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('First page')),
      );
      return;
    }
    final siblings = _bookSiblings(session);
    final activeId =
        _activeSectionId.isNotEmpty ? _activeSectionId : session.id;
    final prev = SectionSiblings.previous(siblings, activeId);
    if (prev == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('First section')),
      );
      return;
    }
    if (!_pdfController.isReady) return;
    _pdfController.goToPage(pageNumber: prev.fromPage);
  }

  void _onPdfNext(ReadingSession session) {
    final continuous = _isContinuousBook(session);
    final hi = continuous
        ? _resolvedPageCount(session)
        : session.toPage;
    final current = _resolvedCurrentPage(session);
    if (current < hi) {
      if (!_pdfController.isReady) return;
      _pdfController.goToPage(pageNumber: current + 1);
      return;
    }
    if (!continuous) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Last page')),
      );
      return;
    }
    final siblings = _bookSiblings(session);
    final activeId =
        _activeSectionId.isNotEmpty ? _activeSectionId : session.id;
    final next = SectionSiblings.next(siblings, activeId);
    if (next == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Last section')),
      );
      return;
    }
    if (!_pdfController.isReady) return;
    _pdfController.goToPage(pageNumber: next.fromPage);
  }

  void _syncPdfPage(ReadingSession opened, int pageNumber) {
    final siblings = _bookSiblings(opened);
    final continuous = siblings.length > 1;
    final active = continuous
        ? (SectionSiblings.atPage(siblings, pageNumber) ?? opened)
        : opened;
    final from = continuous ? active.fromPage : opened.fromPage;
    final to = continuous ? active.toPage : opened.toPage;
    final resolved = _resolvedPageCount(opened);
    final siblingMax = continuous
        ? siblings.map((s) => s.toPage).fold(0, (a, b) => a > b ? a : b)
        : to;
    final total = resolved > siblingMax ? resolved : siblingMax;
    final pageLabel = continuous
        ? '$pageNumber / $total'
        : SectionPageRange.pageLabel(pageNumber, from, to);

    final titleChanged = active.title != _activeSectionTitle;
    final idChanged = active.id != _activeSectionId;
    final pageChanged = pageNumber != _currentPdfPage;
    final labelChanged = pageLabel != _pageLabel;
    final countChanged = total != _documentPageCount;
    if (titleChanged ||
        idChanged ||
        pageChanged ||
        labelChanged ||
        countChanged) {
      setState(() {
        _activeSectionTitle = active.title;
        _activeSectionId = active.id;
        _currentPdfPage = pageNumber;
        _pageLabel = pageLabel;
        _documentPageCount = total;
      });
    }

    final span = (to - from + 1).clamp(1, 999999);
    final relative = ((pageNumber - from + 1) / span).clamp(0.0, 1.0);
    context.read<SessionsCubit>().updateProgress(active.id, relative);
  }

  Future<void> _sendChat(
    ReadingSession session, {
    String? overrideText,
  }) async {
    final text = (overrideText ?? _chatController.text).trim();
    if (text.isEmpty || _loadingChat) return;

    final ready = await ensureFolioAiReady(context);
    if (!mounted) return;
    if (!ready) {
      setState(() {
        _chatExpanded = true;
        _chatError = folioAiNotReadyMessage(
          context.read<SettingsCubit>().state.aiProvider,
        );
        _pendingChat = text;
      });
      return;
    }

    final alreadyShown = overrideText != null &&
        _messages.isNotEmpty &&
        _messages.last.isUser &&
        _messages.last.text == text;

    setState(() {
      if (!alreadyShown) {
        _messages.add(_ChatLine(isUser: true, text: text));
      }
      if (overrideText == null) {
        _chatController.clear();
      }
      _chatExpanded = true;
      _loadingChat = true;
      _chatError = null;
      _pendingChat = text;
    });

    try {
      final settings = context.read<SettingsCubit>().state;
      final ai = FolioAiService(
        apiKey: settings.apiKey,
        provider: settings.aiProvider,
        onDeviceModel: settings.onDeviceModel,
      );
      final contextText = _summaryContextText(_bookFor(session));
      if (contextText.isEmpty) {
        setState(() {
          _messages.add(
            const _ChatLine(
              isUser: false,
              text:
                  'No summaries yet. Summarize some pages first, then ask Folio about them.',
            ),
          );
          _loadingChat = false;
          _pendingChat = null;
        });
        return;
      }
      final reply = await ai.askAboutText(
        contextText: contextText,
        question: text,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatLine(
            isUser: false,
            text: reply.isEmpty ? 'No answer returned.' : reply,
          ),
        );
        _loadingChat = false;
        _chatError = null;
        _pendingChat = null;
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e is NetworkException
          ? e.message
          : e is ApiException
              ? e.message
              : e is StateError
                  ? e.message
                  : 'Could not reach Folio AI.';
      setState(() {
        if (_messages.isNotEmpty &&
            _messages.last.isUser &&
            _messages.last.text == text) {
          _messages.removeLast();
        }
        _loadingChat = false;
        _chatError = msg;
        _pendingChat = text;
      });
    }
  }

  Future<void> _pickDropdown({
    required String title,
    required List<String> options,
    required String current,
    required ValueChanged<String> onPicked,
  }) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: FolioColors.surface,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final o in options)
              ListTile(
                title: Text(o),
                trailing: o == current
                    ? Icon(Icons.check, color: FolioColors.accent)
                    : null,
                onTap: () => Navigator.pop(context, o),
              ),
          ],
        ),
      ),
    );
    if (result != null) onPicked(result);
  }

  Future<void> _pickOnDeviceModel() async {
    final settings = context.read<SettingsCubit>().state;
    final currentId = settings.onDeviceModelId;
    final models = OnDeviceModels.catalog;
    final local = LocalGemmaService.instance;

    final installed = <String, bool>{};
    for (final model in models) {
      installed[model.id] = await local.isInstalled(model);
    }
    if (!mounted) return;

    final picked = await showModalBottomSheet<OnDeviceModel>(
      context: context,
      backgroundColor: FolioColors.surface,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final model in models)
              ListTile(
                title: Text(model.label),
                subtitle: Text(
                  installed[model.id] == true
                      ? model.sizeLabel
                      : '${model.sizeLabel} · Not downloaded',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: FolioColors.textSecondary,
                  ),
                ),
                trailing: model.id == currentId
                    ? Icon(Icons.check, color: FolioColors.accent)
                    : null,
                onTap: () => Navigator.pop(context, model),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;

    if (installed[picked.id] == true) {
      await context.read<SettingsCubit>().setOnDeviceModelId(picked.id);
      return;
    }

    await showLocalModelDownloadSheet(context, model: picked);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.select<SessionsCubit, ReadingSession?>(
      (cubit) {
        try {
          return cubit.state.firstWhere((s) => s.id == widget.sessionId);
        } catch (_) {
          return cubit.state.isNotEmpty ? cubit.state.first : null;
        }
      },
    );

    if (session == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/home'),
          ),
        ),
        body: const Center(child: Text('Session not found')),
      );
    }

    return Scaffold(
      backgroundColor: FolioColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _AppBar(
              title: _activeSectionTitle.isNotEmpty
                  ? _activeSectionTitle
                  : session.title,
              onBack: () => context.go('/home'),
              onShare: () {
                final book = _bookFor(session);
                showExportSheet(
                  context,
                  bullets: _allSummaryBullets(book),
                  title: book?.title ?? session.title,
                );
              },
              onMore: () async {
                final action = await showModalBottomSheet<String>(
                  context: context,
                  backgroundColor: FolioColors.surface,
                  builder: (context) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.auto_awesome_outlined),
                          title: const Text('Summarize pages…'),
                          onTap: () => Navigator.pop(context, 'summarize'),
                        ),
                        ListTile(
                          leading: const Icon(Icons.edit_note_outlined),
                          title: const Text('Custom prompt'),
                          onTap: () => Navigator.pop(context, 'prompt'),
                        ),
                        ListTile(
                          leading: const Icon(Icons.ios_share_outlined),
                          title: const Text('Export summary'),
                          onTap: () => Navigator.pop(context, 'export'),
                        ),
                      ],
                    ),
                  ),
                );
                if (!context.mounted) return;
                if (action == 'summarize') {
                  await _openSummarizeRange(session);
                } else if (action == 'prompt') {
                  final next = await showPromptEditorSheet(
                    context,
                    currentPrompt: _prompt,
                  );
                  if (next != null && context.mounted) {
                    setState(() => _prompt = next);
                    await context.read<SettingsCubit>().setCustomPrompt(next);
                  }
                } else if (action == 'export') {
                  final book = _bookFor(session);
                  await showExportSheet(
                    context,
                    bullets: _allSummaryBullets(book),
                    title: book?.title ?? session.title,
                  );
                }
              },
            ),
            _ToggleBar(
              tab: _tab,
              onChanged: (t) => setState(() => _tab = t),
            ),
            if (_tab == _ReaderTab.summary) ...[
              _FormatBar(
                format: _format,
                length: _length,
                provider: context.select<SettingsCubit, String>(
                  (c) => c.state.aiProvider.label,
                ),
                model: context.select<SettingsCubit, String?>(
                  (c) => c.state.usesOnDeviceAi
                      ? c.state.onDeviceModel.label
                      : null,
                ),
                isRtl: context.select<SettingsCubit, bool>(
                  (c) => c.state.summaryIsRtl,
                ),
                onFormat: () => _pickDropdown(
                  title: 'Format',
                  options: const ['Bullet', 'Paragraph', 'Q&A'],
                  current: _format,
                  onPicked: (v) async {
                    setState(() => _format = v);
                    await context.read<SettingsCubit>().setFormat(v);
                  },
                ),
                onLength: () => _pickDropdown(
                  title: 'Length',
                  options: const ['Short', 'Medium', 'Long'],
                  current: _length,
                  onPicked: (v) async {
                    setState(() => _length = v);
                    await context.read<SettingsCubit>().setLength(v);
                  },
                ),
                onProvider: () {
                  final current =
                      context.read<SettingsCubit>().state.aiProvider.label;
                  _pickDropdown(
                    title: 'AI provider',
                    options:
                        FolioAiProvider.values.map((e) => e.label).toList(),
                    current: current,
                    onPicked: (v) async {
                      final provider = FolioAiProvider.values.firstWhere(
                        (e) => e.label == v,
                        orElse: () => FolioAiProvider.onDevice,
                      );
                      await context.read<SettingsCubit>().setAiProvider(
                            provider,
                          );
                    },
                  );
                },
                onModel: _pickOnDeviceModel,
                onToggleDirection: () {
                  final settings = context.read<SettingsCubit>();
                  final next = settings.state.summaryIsRtl ? 'ltr' : 'rtl';
                  settings.setSummaryTextDirection(next);
                },
              ),
              if (_chatExpanded)
                Expanded(
                  child: _ChatPanel(
                    expanded: true,
                    messages: _messages,
                    loading: _loadingChat,
                    errorMessage: _chatError,
                    controller: _chatController,
                    onToggleExpand: () =>
                        setState(() => _chatExpanded = false),
                    onSend: () => _sendChat(session),
                    onRetry: _pendingChat == null
                        ? null
                        : () =>
                            _sendChat(session, overrideText: _pendingChat),
                  ),
                )
              else ...[
                Expanded(child: _buildSummaryBody(session)),
                _ChatPanel(
                  expanded: false,
                  messages: _messages,
                  loading: _loadingChat,
                  errorMessage: _chatError,
                  controller: _chatController,
                  onToggleExpand: () =>
                      setState(() => _chatExpanded = true),
                  onSend: () => _sendChat(session),
                  onRetry: _pendingChat == null
                      ? null
                      : () =>
                          _sendChat(session, overrideText: _pendingChat),
                ),
              ],
            ] else
              Expanded(child: _buildPdfTab(session)),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryBody(ReadingSession session) {
    final isRtl = context.select<SettingsCubit, bool>(
      (c) => c.state.summaryIsRtl,
    );
    final direction = isRtl ? TextDirection.rtl : TextDirection.ltr;
    final book = context.select<BooksCubit, Book?>(
      (c) => session.bookId == null ? null : c.byId(session.bookId!),
    );
    final segments = book?.orderedSummarySegments ?? const <SummarySegment>[];

    if (_loadingSummary) {
      return BlocBuilder<SummarizeJobCubit, SummarizeJobState?>(
        builder: (context, job) {
          if (job != null && job.sessionId == session.id) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: _ReaderSummarizeEta(
                  job: job,
                  onCancel: () =>
                      context.read<SummarizeJobCubit>().requestCancel(),
                ),
              ),
            );
          }
          return const FolioSummarySkeleton();
        },
      );
    }

    if (_summaryError != null && segments.isEmpty) {
      return FolioSummaryErrorState(
        message: _summaryError!,
        onRegenerate: () => _openSummarizeRange(session),
        onOpenApiKey: () async {
          final saved = await showApiKeyGateSheet(context, editing: true);
          if (saved && mounted) await _openSummarizeRange(session);
        },
      );
    }

    if (segments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.auto_awesome_outlined,
                size: 40,
                color: FolioColors.accent,
              ),
              const SizedBox(height: 16),
              Text(
                'No summaries yet',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: FolioColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Open the PDF, then choose a page range to summarize. '
                'Each range is saved as its own section here.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.5,
                  color: FolioColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 220,
                child: FolioPrimaryButton(
                  label: 'Summarize pages…',
                  onPressed: session.hasLocalPdf
                      ? () => _openSummarizeRange(session)
                      : null,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Directionality(
      textDirection: direction,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          if (_summaryError != null) ...[
            FolioInlineErrorBanner(
              message: _summaryError!,
              onRetry: () => _openSummarizeRange(session),
              retryLabel: 'Try again',
            ),
            const SizedBox(height: 16),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: session.hasLocalPdf
                  ? () => _openSummarizeRange(session)
                  : null,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Summarize more pages'),
            ),
          ),
          const SizedBox(height: 8),
          for (final segment in segments) ...[
            _SummarySegmentCard(
              segment: segment,
              isRtl: isRtl,
              onRegenerate: () =>
                  _regenerateSegmentWithPrompt(session, segment),
              onDelete: () => _deleteSegment(session, segment.id),
              onRestoreRevision: (index) =>
                  _restoreSummaryRevision(session, segment, index),
              onAnnotate: (quote) {
                final store = context.read<LocalStore>();
                final messenger = ScaffoldMessenger.of(context);
                showAnnotationSheet(
                  context,
                  quote: quote,
                  onSave: (note) async {
                    await store.addAnnotation(
                      SessionAnnotation(
                        sessionId: session.id,
                        quote: quote,
                        note: note,
                        createdAt: DateTime.now(),
                      ),
                    );
                    if (!mounted) return;
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          note.isEmpty
                              ? 'Annotation saved'
                              : 'Note saved: $note',
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }

  Widget _buildPdfTab(ReadingSession session) {
    if (!session.hasLocalPdf) {
      return const _PdfTabStub();
    }

    final continuous = _isContinuousBook(session);
    final from = session.fromPage;
    final to = session.toPage;
    final preferred = widget.initialPage;
    final initial = continuous
        ? (preferred ?? from).clamp(1, 999999)
        : SectionPageRange.clampPage(preferred ?? from, from, to);
    final viewerKey = continuous
        ? 'pdf-book-${session.bookId}-${session.localPath}'
        : 'pdf-${session.id}-$initial';
    final sectionTitle = _activeSectionTitle.isNotEmpty
        ? _activeSectionTitle
        : session.title;
    final pageText = _pageLabel == '– / –'
        ? (continuous
            ? '$initial'
            : SectionPageRange.pageLabel(initial, from, to))
        : _pageLabel;

    return Column(
      children: [
        Expanded(
          child: PdfViewer.file(
            session.localPath!,
            key: ValueKey(viewerKey),
            controller: _pdfController,
            initialPageNumber: initial,
            params: PdfViewerParams(
              backgroundColor: FolioColors.background,
              layoutPages: continuous
                  ? null
                  : (pages, params) => SectionPageRange.layoutPagesOnly(
                        pages: pages,
                        params: params,
                        fromPage: from,
                        toPage: to,
                      ),
              onPageChanged: (pageNumber) {
                if (pageNumber == null) return;
                if (continuous) {
                  _syncPdfPage(session, pageNumber);
                  return;
                }
                final clamped =
                    SectionPageRange.clampPage(pageNumber, from, to);
                if (clamped != pageNumber) {
                  _pdfController.goToPage(pageNumber: clamped);
                  return;
                }
                _syncPdfPage(session, clamped);
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: FolioColors.surface,
              borderRadius: BorderRadius.circular(FolioColors.radiusCard),
              border: Border.all(color: FolioColors.border),
            ),
            child: Row(
              children: [
                _ZoomBtn(
                  Icons.remove,
                  onTap: () => _pdfController.zoomDown(),
                ),
                const SizedBox(width: 4),
                _ZoomBtn(
                  Icons.add,
                  onTap: () => _pdfController.zoomUp(),
                ),
                const SizedBox(width: 8),
                _ZoomBtn(
                  Icons.chevron_left,
                  onTap: () => _onPdfPrev(session),
                ),
                _ZoomBtn(
                  Icons.chevron_right,
                  onTap: () => _onPdfNext(session),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (continuous)
                        Text(
                          sectionTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: FolioColors.textSecondary,
                          ),
                        ),
                      Text(
                        pageText,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _ZoomBtn(
                  Icons.fit_screen_outlined,
                  onTap: () {
                    final page = continuous
                        ? (_pdfController.pageNumber ?? initial)
                        : SectionPageRange.clampPage(
                            _pdfController.pageNumber ?? from,
                            from,
                            to,
                          );
                    _pdfController.goToPage(pageNumber: page);
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

enum _ReaderTab { summary, pdf }

class _SummarySegmentCard extends StatefulWidget {
  const _SummarySegmentCard({
    required this.segment,
    required this.isRtl,
    required this.onRegenerate,
    required this.onDelete,
    required this.onRestoreRevision,
    required this.onAnnotate,
  });

  final SummarySegment segment;
  final bool isRtl;
  final VoidCallback onRegenerate;
  final VoidCallback onDelete;
  final ValueChanged<int> onRestoreRevision;
  final ValueChanged<String> onAnnotate;

  @override
  State<_SummarySegmentCard> createState() => _SummarySegmentCardState();
}

class _SummarySegmentCardState extends State<_SummarySegmentCard> {
  var _expanded = true;
  var _historyExpanded = false;

  SummarySegment get segment => widget.segment;

  String _formatWhen(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} · $h:$m';
  }

  Widget _bulletRow(String text) {
    return InkWell(
      onLongPress: () => widget.onAnnotate(text),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 7),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: FolioColors.accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              textAlign: widget.isRtl ? TextAlign.right : TextAlign.left,
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.6,
                color: FolioColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FolioColors.surface,
        borderRadius: BorderRadius.circular(FolioColors.radiusCard),
        border: Border.all(color: FolioColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _expanded = !_expanded),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          _expanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                          size: 20,
                          color: FolioColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            segment.pageRangeLabel,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: FolioColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Regenerate',
                onPressed: widget.onRegenerate,
                icon: const Icon(Icons.refresh, size: 18),
                color: FolioColors.textSecondary,
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                tooltip: 'Delete',
                onPressed: widget.onDelete,
                icon: const Icon(Icons.delete_outline, size: 18),
                color: FolioColors.textSecondary,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          if (_expanded) ...[
            const SizedBox(height: 8),
            for (var i = 0; i < segment.bullets.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _bulletRow(segment.bullets[i]),
            ],
            if (segment.previousVersions.isNotEmpty) ...[
              const SizedBox(height: 14),
              InkWell(
                onTap: () =>
                    setState(() => _historyExpanded = !_historyExpanded),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        _historyExpanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        size: 18,
                        color: FolioColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Previous versions (${segment.previousVersions.length})',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: FolioColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_historyExpanded) ...[
                for (var v = 0; v < segment.previousVersions.length; v++) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: FolioColors.surfaceElevated,
                      borderRadius:
                          BorderRadius.circular(FolioColors.radiusCard),
                      border: Border.all(color: FolioColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _formatWhen(
                                  segment.previousVersions[v].createdAt,
                                ),
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: FolioColors.textDim,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () =>
                                  widget.onRestoreRevision(v),
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                              ),
                              child: Text(
                                'Restore',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: FolioColors.accent,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        for (var i = 0;
                            i < segment.previousVersions[v].bullets.length;
                            i++) ...[
                          if (i > 0) const SizedBox(height: 8),
                          Text(
                            '• ${segment.previousVersions[v].bullets[i]}',
                            textAlign: widget.isRtl
                                ? TextAlign.right
                                : TextAlign.left,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              height: 1.5,
                              color: FolioColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ],
        ],
      ),
    );
  }
}

class _AppBar extends StatelessWidget {
  const _AppBar({
    required this.title,
    required this.onBack,
    required this.onShare,
    required this.onMore,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback onShare;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: FolioColors.border)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back),
            color: FolioColors.textPrimary,
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: onShare,
            icon: const Icon(Icons.ios_share_outlined, size: 20),
            color: FolioColors.textPrimary,
          ),
          IconButton(
            onPressed: onMore,
            icon: const Icon(Icons.more_vert, size: 20),
            color: FolioColors.textPrimary,
          ),
        ],
      ),
    );
  }
}

class _ToggleBar extends StatelessWidget {
  const _ToggleBar({required this.tab, required this.onChanged});

  final _ReaderTab tab;
  final ValueChanged<_ReaderTab> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget tabItem(String label, _ReaderTab value) {
      final active = tab == value;
      return Expanded(
        child: InkWell(
          onTap: () => onChanged(value),
          child: Container(
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: active ? FolioColors.accent : FolioColors.border,
                  width: active ? 2 : 1,
                ),
              ),
            ),
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active
                    ? FolioColors.textPrimary
                    : FolioColors.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tabItem('Original PDF', _ReaderTab.pdf),
        tabItem('Summary', _ReaderTab.summary),
      ],
    );
  }
}

class _FormatBar extends StatelessWidget {
  const _FormatBar({
    required this.format,
    required this.length,
    required this.provider,
    required this.isRtl,
    required this.onFormat,
    required this.onLength,
    required this.onProvider,
    required this.onToggleDirection,
    this.model,
    this.onModel,
  });

  final String format;
  final String length;
  final String provider;
  final String? model;
  final bool isRtl;
  final VoidCallback onFormat;
  final VoidCallback onLength;
  final VoidCallback onProvider;
  final VoidCallback? onModel;
  final VoidCallback onToggleDirection;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, VoidCallback onTap) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(FolioColors.radiusButton),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(FolioColors.radiusButton),
            border: Border.all(color: FolioColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: FolioColors.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down,
                size: 16,
                color: FolioColors.textSecondary,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
      color: FolioColors.surfaceElevated,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                chip(format, onFormat),
                chip(length, onLength),
                chip(provider, onProvider),
                if (model != null && onModel != null) chip(model!, onModel!),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onToggleDirection,
            icon: Icon(
              isRtl
                  ? Icons.format_textdirection_r_to_l
                  : Icons.format_textdirection_l_to_r,
              size: 18,
              color: FolioColors.accent,
            ),
            label: Text(
              isRtl ? 'RTL' : 'LTR',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: FolioColors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatLine {
  const _ChatLine({required this.isUser, required this.text});
  final bool isUser;
  final String text;
}

class _ChatPanel extends StatelessWidget {
  const _ChatPanel({
    required this.expanded,
    required this.messages,
    required this.loading,
    required this.errorMessage,
    required this.controller,
    required this.onToggleExpand,
    required this.onSend,
    this.onRetry,
  });

  final bool expanded;
  final List<_ChatLine> messages;
  final bool loading;
  final String? errorMessage;
  final TextEditingController controller;
  final VoidCallback onToggleExpand;
  final VoidCallback onSend;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final body = Column(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onToggleExpand,
          behavior: HitTestBehavior.opaque,
          child: Column(
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: FolioColors.textDim,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Ask Folio',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,
                    color: FolioColors.textSecondary,
                  ),
                ],
              ),
            ],
          ),
        ),
        if (expanded) ...[
          const SizedBox(height: 12),
          if (errorMessage != null) ...[
            FolioInlineErrorBanner(
              message: errorMessage!,
              onRetry: onRetry,
            ),
            const SizedBox(height: 12),
          ],
          Expanded(
            child: ListView.separated(
              itemCount: messages.length + (loading ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                if (loading && i == messages.length) {
                  return const FolioTypingIndicator();
                }
                final m = messages[i];
                return Align(
                  alignment:
                      m.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width * 0.75,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: m.isUser
                          ? FolioColors.accent
                          : FolioColors.surfaceElevated,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(12),
                        topRight: const Radius.circular(12),
                        bottomLeft: Radius.circular(m.isUser ? 12 : 4),
                        bottomRight: Radius.circular(m.isUser ? 4 : 12),
                      ),
                    ),
                    child: Text(
                      m.text,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.4,
                        color: FolioColors.textPrimary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: !loading,
                  style: GoogleFonts.inter(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Ask Folio...',
                    filled: true,
                    fillColor: FolioColors.surfaceElevated,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: FolioColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: FolioColors.border),
                    ),
                  ),
                  onSubmitted: loading ? null : (_) => onSend(),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: loading
                    ? FolioColors.surfaceElevated
                    : FolioColors.accent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: loading ? null : onSend,
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(
                      Icons.arrow_upward,
                      color: FolioColors.onAccent,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: FolioColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(FolioColors.radiusSheet),
        ),
        border: Border(top: BorderSide(color: FolioColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: body,
    );
  }
}

class _PdfTabStub extends StatelessWidget {
  const _PdfTabStub();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: FolioColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: FolioColors.border),
            ),
            child: Icon(
              Icons.picture_as_pdf_outlined,
              color: FolioColors.accent,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'PDF unavailable',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Import a PDF to open the original document viewer.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.45,
              color: FolioColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReaderSummarizeEta extends StatefulWidget {
  const _ReaderSummarizeEta({
    required this.job,
    required this.onCancel,
  });

  final SummarizeJobState job;
  final VoidCallback onCancel;

  @override
  State<_ReaderSummarizeEta> createState() => _ReaderSummarizeEtaState();
}

class _ReaderSummarizeEtaState extends State<_ReaderSummarizeEta> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed =
        DateTime.now().difference(widget.job.startedAt).inSeconds.clamp(0, 9999);
    final eta = widget.job.etaSeconds;
    final progress = (elapsed / eta).clamp(0.0, 0.9);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 56,
          height: 56,
          child: CircularProgressIndicator(
            value: progress,
            strokeWidth: 3.5,
            color: FolioColors.accent,
            backgroundColor: FolioColors.surfaceElevated,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          widget.job.cancelRequested ? 'Cancelling…' : 'Summarizing…',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: FolioColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          widget.job.cancelRequested
              ? 'Stopping this summary'
              : 'About ${SummarizeEta.label(eta)} · ${elapsed}s elapsed',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: FolioColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: 160,
          child: FolioSecondaryButton(
            label: 'Cancel',
            onPressed: widget.job.cancelRequested ? null : widget.onCancel,
          ),
        ),
      ],
    );
  }
}

class _ZoomBtn extends StatelessWidget {
  const _ZoomBtn(this.icon, {this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: FolioColors.surfaceElevated,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: FolioColors.border),
          ),
          child: Icon(icon, size: 18, color: FolioColors.textPrimary),
        ),
      ),
    );
  }
}
