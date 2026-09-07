import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nexus_chat/core/storage/local_store.dart';
import 'package:nexus_chat/core/theme/folio_colors.dart';
import 'package:nexus_chat/core/widgets/folio_buttons.dart';
import 'package:nexus_chat/core/widgets/folio_feedback.dart';
import 'package:nexus_chat/features/chat/data/api_exception.dart';
import 'package:nexus_chat/features/chat/data/network_exception.dart';
import 'package:nexus_chat/features/reader/data/folio_ai_service.dart';
import 'package:nexus_chat/features/reader/data/section_summarizer.dart';
import 'package:nexus_chat/features/reader/domain/section_page_range.dart';
import 'package:nexus_chat/features/reader/presentation/widgets/reader_sheets.dart';
import 'package:nexus_chat/features/sessions/domain/reading_session.dart';
import 'package:nexus_chat/features/sessions/presentation/cubit/sessions_cubit.dart';
import 'package:nexus_chat/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:nexus_chat/features/settings/presentation/widgets/api_key_gate_sheet.dart';
import 'package:pdfrx/pdfrx.dart';

class ReaderPage extends StatefulWidget {
  const ReaderPage({
    super.key,
    required this.sessionId,
    this.initialTab = 'pdf',
  });

  final String sessionId;
  /// `pdf` or `summary`
  final String initialTab;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  late _ReaderTab _tab;
  var _format = 'Bullet';
  var _length = 'Medium';
  var _chatExpanded = false;
  var _chatScope = 'Section';
  var _prompt = FolioAiService.defaultPrompt;
  var _loadingSummary = false;
  var _loadingChat = false;
  List<String> _bullets = const [];
  String? _summaryError;
  String? _chatError;
  String? _pendingChat;
  Uint8List? _pdfBytes;
  final _chatController = TextEditingController();
  final _messages = <_ChatLine>[];
  final _pdfController = PdfViewerController();
  var _pageLabel = '– / –';

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
        _chatScope = settings.chatScope;
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

    if (session.hasSummary) {
      setState(() {
        _bullets = session.summaryBullets;
        _summaryError = null;
        _loadingSummary = false;
      });
    }

    if (session.hasLocalPdf) {
      try {
        final bytes = await File(session.localPath!).readAsBytes();
        if (!mounted) return;
        setState(() => _pdfBytes = bytes);
        // Do not auto-summarize on open — user triggers explicitly.
      } catch (_) {
        if (!mounted) return;
        setState(() {
          if (!session.hasSummary) {
            _summaryError = 'Could not read the PDF file.';
            _bullets = const [];
          }
        });
      }
    }
  }

  Future<void> _summarize(ReadingSession session) async {
    final hasKey = await ensureFolioApiKey(context);
    if (!mounted) return;
    if (!hasKey) {
      setState(() {
        _loadingSummary = false;
        _summaryError =
            'GEMINI_API_KEY is missing. Add it in Settings or your .env file.';
      });
      return;
    }

    setState(() {
      _loadingSummary = true;
      _summaryError = null;
    });

    try {
      final settings = context.read<SettingsCubit>().state;
      final bullets = await const SectionSummarizer().summarize(
        session: session,
        sessions: context.read<SessionsCubit>(),
        apiKey: settings.apiKey,
        format: _format,
        length: _length,
        customPrompt: _prompt,
      );
      if (!mounted) return;
      setState(() {
        _bullets = bullets;
        _loadingSummary = false;
        _summaryError = null;
      });
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
    }
  }

  Future<void> _sendChat(
    ReadingSession session, {
    String? overrideText,
  }) async {
    final text = (overrideText ?? _chatController.text).trim();
    if (text.isEmpty || _loadingChat) return;

    final hasKey = await ensureFolioApiKey(context);
    if (!mounted) return;
    if (!hasKey) {
      setState(() {
        _chatExpanded = true;
        _chatError =
            'GEMINI_API_KEY is missing. Add it in Settings or your .env file.';
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
      if (_pdfBytes == null) {
        setState(() {
          _messages.add(
            const _ChatLine(
              isUser: false,
              text:
                  'Import a PDF to enable Folio answers grounded in your document.',
            ),
          );
          _loadingChat = false;
          _pendingChat = null;
        });
        return;
      }

      final apiKey = context.read<SettingsCubit>().state.apiKey;
      final reply = await FolioAiService(apiKey: apiKey).askAboutPdf(
        pdfBytes: _pdfBytes!,
        question: text,
        scope: _chatScope,
        fromPage: session.fromPage,
        toPage: session.toPage,
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
                    ? const Icon(Icons.check, color: FolioColors.accent)
                    : null,
                onTap: () => Navigator.pop(context, o),
              ),
          ],
        ),
      ),
    );
    if (result != null) onPicked(result);
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
              title: session.title,
              onBack: () {
                final bookId = session.bookId;
                if (bookId != null && bookId.isNotEmpty) {
                  context.go('/book/$bookId');
                } else {
                  context.go('/home');
                }
              },
              onShare: () => showExportSheet(
                context,
                bullets: _bullets,
                title: session.title,
              ),
              onMore: () async {
                final action = await showModalBottomSheet<String>(
                  context: context,
                  backgroundColor: FolioColors.surface,
                  builder: (context) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
                if (action == 'prompt') {
                  final next = await showPromptEditorSheet(
                    context,
                    currentPrompt: _prompt,
                  );
                  if (next != null && context.mounted) {
                    setState(() => _prompt = next);
                    await context.read<SettingsCubit>().setCustomPrompt(next);
                    await _summarize(session);
                  }
                } else if (action == 'export') {
                  await showExportSheet(
                    context,
                    bullets: _bullets,
                    title: session.title,
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
                isRtl: context.select<SettingsCubit, bool>(
                  (c) => c.state.summaryIsRtl,
                ),
                onFormat: () => _pickDropdown(
                  title: 'Format',
                  options: const ['Bullet', 'Paragraph', 'Q&A'],
                  current: _format,
                  onPicked: (v) async {
                    setState(() => _format = v);
                    if (_bullets.isNotEmpty || session.hasSummary) {
                      await _summarize(session);
                    }
                  },
                ),
                onLength: () => _pickDropdown(
                  title: 'Length',
                  options: const ['Short', 'Medium', 'Long'],
                  current: _length,
                  onPicked: (v) async {
                    setState(() => _length = v);
                    if (_bullets.isNotEmpty || session.hasSummary) {
                      await _summarize(session);
                    }
                  },
                ),
                onToggleDirection: () {
                  final settings = context.read<SettingsCubit>();
                  final next = settings.state.summaryIsRtl ? 'ltr' : 'rtl';
                  settings.setSummaryTextDirection(next);
                },
              ),
              Expanded(child: _buildSummaryBody(session)),
              _ChatPanel(
                expanded: _chatExpanded,
                scope: _chatScope,
                messages: _messages,
                loading: _loadingChat,
                errorMessage: _chatError,
                controller: _chatController,
                onToggleExpand: () =>
                    setState(() => _chatExpanded = !_chatExpanded),
                onScopeChanged: (s) => setState(() => _chatScope = s),
                onSend: () => _sendChat(session),
                onRetry: _pendingChat == null
                    ? null
                    : () => _sendChat(session, overrideText: _pendingChat),
              ),
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

    if (_loadingSummary) {
      return const FolioSummarySkeleton();
    }

    if (_summaryError != null && _bullets.isEmpty) {
      return FolioSummaryErrorState(
        message: _summaryError!,
        onRegenerate: () => _summarize(session),
        onOpenApiKey: () async {
          final saved = await showApiKeyGateSheet(context, editing: true);
          if (saved && mounted) await _summarize(session);
        },
      );
    }

    if (_bullets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.auto_awesome_outlined,
                size: 40,
                color: FolioColors.accent,
              ),
              const SizedBox(height: 16),
              Text(
                'No summary yet',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: FolioColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Generate an AI summary for pages ${session.fromPage}–${session.toPage}.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.5,
                  color: FolioColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 200,
                child: FolioPrimaryButton(
                  label: 'Summarize',
                  onPressed: session.hasLocalPdf
                      ? () => _summarize(session)
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
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        children: [
          if (_summaryError != null) ...[
            FolioInlineErrorBanner(
              message: _summaryError!,
              onRetry: () => _summarize(session),
              retryLabel: 'Regenerate',
            ),
            const SizedBox(height: 16),
          ],
          if (!session.hasLocalPdf)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'This session has no local PDF. Import a file to generate live summaries.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: FolioColors.textSecondary,
                ),
              ),
            ),
          for (var i = 0; i < _bullets.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            InkWell(
              onLongPress: () {
                final store = context.read<LocalStore>();
                final messenger = ScaffoldMessenger.of(context);
                showAnnotationSheet(
                  context,
                  quote: _bullets[i],
                  onSave: (note) async {
                    await store.addAnnotation(
                      SessionAnnotation(
                        sessionId: session.id,
                        quote: _bullets[i],
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 7),
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: FolioColors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _bullets[i],
                      textAlign: isRtl ? TextAlign.right : TextAlign.left,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        height: 1.6,
                        color: FolioColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPdfTab(ReadingSession session) {
    if (!session.hasLocalPdf) {
      return const _PdfTabStub();
    }

    final from = session.fromPage;
    final to = session.toPage;
    final initial = SectionPageRange.clampPage(from, from, to);

    return Column(
      children: [
        Expanded(
          child: PdfViewer.file(
            session.localPath!,
            controller: _pdfController,
            initialPageNumber: initial,
            params: PdfViewerParams(
              backgroundColor: FolioColors.background,
              layoutPages: (pages, params) => SectionPageRange.layoutPagesOnly(
                pages: pages,
                params: params,
                fromPage: from,
                toPage: to,
              ),
              onPageChanged: (pageNumber) {
                if (pageNumber == null) return;
                final clamped =
                    SectionPageRange.clampPage(pageNumber, from, to);
                if (clamped != pageNumber) {
                  _pdfController.goToPage(pageNumber: clamped);
                  return;
                }
                setState(() {
                  _pageLabel = SectionPageRange.pageLabel(clamped, from, to);
                });
                final span = (to - from + 1).clamp(1, 999999);
                final relative =
                    ((clamped - from + 1) / span).clamp(0.0, 1.0);
                context
                    .read<SessionsCubit>()
                    .updateProgress(session.id, relative);
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
                  onTap: () {
                    final current = _pdfController.pageNumber ?? from;
                    final prev = SectionPageRange.clampPage(
                      current - 1,
                      from,
                      to,
                    );
                    _pdfController.goToPage(pageNumber: prev);
                  },
                ),
                _ZoomBtn(
                  Icons.chevron_right,
                  onTap: () {
                    final current = _pdfController.pageNumber ?? from;
                    final next = SectionPageRange.clampPage(
                      current + 1,
                      from,
                      to,
                    );
                    _pdfController.goToPage(pageNumber: next);
                  },
                ),
                const Spacer(),
                Text(
                  _pageLabel == '– / –'
                      ? SectionPageRange.pageLabel(initial, from, to)
                      : _pageLabel,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                _ZoomBtn(
                  Icons.fit_screen_outlined,
                  onTap: () {
                    final page = SectionPageRange.clampPage(
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
      decoration: const BoxDecoration(
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
    required this.isRtl,
    required this.onFormat,
    required this.onLength,
    required this.onToggleDirection,
  });

  final String format;
  final String length;
  final bool isRtl;
  final VoidCallback onFormat;
  final VoidCallback onLength;
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
              const Icon(
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
        children: [
          chip(format, onFormat),
          const SizedBox(width: 8),
          chip(length, onLength),
          const Spacer(),
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
    required this.scope,
    required this.messages,
    required this.loading,
    required this.errorMessage,
    required this.controller,
    required this.onToggleExpand,
    required this.onScopeChanged,
    required this.onSend,
    this.onRetry,
  });

  final bool expanded;
  final String scope;
  final List<_ChatLine> messages;
  final bool loading;
  final String? errorMessage;
  final TextEditingController controller;
  final VoidCallback onToggleExpand;
  final ValueChanged<String> onScopeChanged;
  final VoidCallback onSend;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: FolioColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(FolioColors.radiusSheet),
        ),
        border: Border(top: BorderSide(color: FolioColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
                    if (expanded)
                      _ScopeToggle(scope: scope, onChanged: onScopeChanged)
                    else
                      const Icon(
                        Icons.keyboard_arrow_up,
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
            SizedBox(
              height: 160,
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
                        borderSide: const BorderSide(color: FolioColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: FolioColors.border),
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
                    child: const SizedBox(
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
      ),
    );
  }
}

class _ScopeToggle extends StatelessWidget {
  const _ScopeToggle({required this.scope, required this.onChanged});

  final String scope;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget pill(String label) {
      final active = scope == label;
      return GestureDetector(
        onTap: () => onChanged(label),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: active ? FolioColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color:
                  active ? FolioColors.onAccent : FolioColors.textSecondary,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: FolioColors.surfaceElevated,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [pill('Section'), pill('Full PDF')],
      ),
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
            child: const Icon(
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
