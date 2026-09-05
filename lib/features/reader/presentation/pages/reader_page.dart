import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nexus_chat/core/storage/local_store.dart';
import 'package:nexus_chat/core/theme/folio_colors.dart';
import 'package:nexus_chat/features/chat/data/api_exception.dart';
import 'package:nexus_chat/features/chat/data/network_exception.dart';
import 'package:nexus_chat/features/reader/data/folio_ai_service.dart';
import 'package:nexus_chat/features/reader/presentation/widgets/reader_sheets.dart';
import 'package:nexus_chat/features/sessions/domain/reading_session.dart';
import 'package:nexus_chat/features/sessions/presentation/cubit/sessions_cubit.dart';
import 'package:nexus_chat/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:pdfrx/pdfrx.dart';

class ReaderPage extends StatefulWidget {
  const ReaderPage({super.key, required this.sessionId});

  final String sessionId;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  var _tab = _ReaderTab.summary;
  var _format = 'Bullet';
  var _length = 'Medium';
  var _chatExpanded = false;
  var _chatScope = 'Section';
  var _prompt = FolioAiService.defaultPrompt;
  var _loadingSummary = false;
  var _loadingChat = false;
  List<String> _bullets = const [];
  String? _summaryError;
  Uint8List? _pdfBytes;
  final _chatController = TextEditingController();
  final _messages = <_ChatLine>[];
  final _pdfController = PdfViewerController();
  var _pageLabel = '– / –';

  static const _fallbackBullets = [
    'The Transformer architecture entirely eschews recurrence and convolutions, relying solely on self-attention mechanisms.',
    'Self-attention allows the model to capture dependencies between words regardless of their distance.',
    'Multi-head attention lets the model jointly attend to information from different representation subspaces.',
    'Positional encodings inject order information without recurrence.',
    'Training time is reduced compared to recurrent sequence models of similar quality.',
  ];

  @override
  void initState() {
    super.initState();
    _bullets = List.of(_fallbackBullets);
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

    if (session.hasLocalPdf) {
      try {
        final bytes = await File(session.localPath!).readAsBytes();
        if (!mounted) return;
        setState(() => _pdfBytes = bytes);
        await _summarize(session);
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _summaryError = 'Could not read the PDF file.';
        });
      }
    }
  }

  Future<void> _summarize(ReadingSession session) async {
    if (_pdfBytes == null) {
      setState(() {
        _bullets = List.of(_fallbackBullets);
        _summaryError = null;
      });
      return;
    }

    setState(() {
      _loadingSummary = true;
      _summaryError = null;
    });

    try {
      final apiKey = context.read<SettingsCubit>().state.apiKey;
      final ai = FolioAiService(apiKey: apiKey);
      final bullets = await ai.summarizePdf(
        pdfBytes: _pdfBytes!,
        format: _format,
        length: _length,
        customPrompt: _prompt,
        fromPage: session.fromPage,
        toPage: session.toPage,
      );
      if (!mounted) return;
      setState(() {
        _bullets = bullets;
        _loadingSummary = false;
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
        _summaryError = 'Summarization failed. Showing sample bullets.';
        _bullets = List.of(_fallbackBullets);
      });
    }
  }

  Future<void> _sendChat(ReadingSession session) async {
    final text = _chatController.text.trim();
    if (text.isEmpty || _loadingChat) return;

    setState(() {
      _messages.add(_ChatLine(isUser: true, text: text));
      _chatController.clear();
      _chatExpanded = true;
      _loadingChat = true;
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
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e is NetworkException
          ? e.message
          : e is ApiException
              ? e.message
              : 'Could not reach Folio AI.';
      setState(() {
        _messages.add(_ChatLine(isUser: false, text: msg));
        _loadingChat = false;
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
              onBack: () => context.go('/home'),
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
                onFormat: () => _pickDropdown(
                  title: 'Format',
                  options: const ['Bullet', 'Paragraph', 'Q&A'],
                  current: _format,
                  onPicked: (v) async {
                    setState(() => _format = v);
                    await _summarize(session);
                  },
                ),
                onLength: () => _pickDropdown(
                  title: 'Length',
                  options: const ['Short', 'Medium', 'Long'],
                  current: _length,
                  onPicked: (v) async {
                    setState(() => _length = v);
                    await _summarize(session);
                  },
                ),
              ),
              Expanded(child: _buildSummaryBody(session)),
              _ChatPanel(
                expanded: _chatExpanded,
                scope: _chatScope,
                messages: _messages,
                loading: _loadingChat,
                controller: _chatController,
                onToggleExpand: () =>
                    setState(() => _chatExpanded = !_chatExpanded),
                onScopeChanged: (s) => setState(() => _chatScope = s),
                onSend: () => _sendChat(session),
              ),
            ] else
              Expanded(child: _buildPdfTab(session)),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryBody(ReadingSession session) {
    if (_loadingSummary) {
      return const Center(
        child: CircularProgressIndicator(color: FolioColors.accent),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      children: [
        if (_summaryError != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: FolioColors.offlineBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: FolioColors.danger),
            ),
            child: Text(
              _summaryError!,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: FolioColors.offlineText,
              ),
            ),
          ),
        ],
        if (!session.hasLocalPdf)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Demo session — sample summary. Import a PDF for live Gemini summaries.',
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
                        note.isEmpty ? 'Annotation saved' : 'Note saved: $note',
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
    );
  }

  Widget _buildPdfTab(ReadingSession session) {
    if (!session.hasLocalPdf) {
      return const _PdfTabStub();
    }

    return Column(
      children: [
        Expanded(
          child: PdfViewer.file(
            session.localPath!,
            controller: _pdfController,
            initialPageNumber: session.fromPage.clamp(1, 9999),
            params: PdfViewerParams(
              backgroundColor: FolioColors.background,
              onPageChanged: (pageNumber) {
                final total = _pdfController.pageCount;
                setState(() {
                  _pageLabel =
                      '${pageNumber ?? '–'} / ${total > 0 ? total : '–'}';
                });
                if (pageNumber != null && total > 0) {
                  final span = (session.toPage - session.fromPage + 1)
                      .clamp(1, total);
                  final relative =
                      ((pageNumber - session.fromPage + 1) / span)
                          .clamp(0.0, 1.0);
                  context
                      .read<SessionsCubit>()
                      .updateProgress(session.id, relative);
                }
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                const SizedBox(width: 8),
                _ZoomBtn(
                  Icons.add,
                  onTap: () => _pdfController.zoomUp(),
                ),
                const Spacer(),
                Text(
                  _pageLabel,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                _ZoomBtn(
                  Icons.fit_screen_outlined,
                  onTap: () {
                    final page = _pdfController.pageNumber ?? 1;
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
        tabItem('Summary', _ReaderTab.summary),
        tabItem('Original PDF', _ReaderTab.pdf),
      ],
    );
  }
}

class _FormatBar extends StatelessWidget {
  const _FormatBar({
    required this.format,
    required this.length,
    required this.onFormat,
    required this.onLength,
  });

  final String format;
  final String length;
  final VoidCallback onFormat;
  final VoidCallback onLength;

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
      padding: const EdgeInsets.all(12),
      color: FolioColors.surfaceElevated,
      child: Row(
        children: [
          chip(format, onFormat),
          const SizedBox(width: 8),
          chip(length, onLength),
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
    required this.controller,
    required this.onToggleExpand,
    required this.onScopeChanged,
    required this.onSend,
  });

  final bool expanded;
  final String scope;
  final List<_ChatLine> messages;
  final bool loading;
  final TextEditingController controller;
  final VoidCallback onToggleExpand;
  final ValueChanged<String> onScopeChanged;
  final VoidCallback onSend;

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
            SizedBox(
              height: 160,
              child: ListView.separated(
                itemCount: messages.length + (loading ? 1 : 0),
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  if (loading && i == messages.length) {
                    return const Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: FolioColors.accent,
                          ),
                        ),
                      ),
                    );
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
                    onSubmitted: (_) => onSend(),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: FolioColors.accent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onSend,
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
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: FolioColors.pdfPage,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: FolioColors.border),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Attention Is All You Need',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: FolioColors.pdfText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Demo preview — import a PDF to open the real viewer.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: FolioColors.textDim,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: FolioColors.surface,
              borderRadius: BorderRadius.circular(FolioColors.radiusCard),
              border: Border.all(color: FolioColors.border),
            ),
            child: Row(
              children: [
                const _ZoomBtn(Icons.remove),
                const SizedBox(width: 8),
                const _ZoomBtn(Icons.add),
                const Spacer(),
                Text(
                  '12 / 45',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                const _ZoomBtn(Icons.fit_screen_outlined),
              ],
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
