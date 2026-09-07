import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nexus_chat/core/theme/folio_colors.dart';
import 'package:nexus_chat/core/widgets/folio_buttons.dart';
import 'package:nexus_chat/features/books/domain/book.dart';
import 'package:nexus_chat/features/books/presentation/cubit/books_cubit.dart';
import 'package:nexus_chat/features/sessions/domain/reading_session.dart';

class ManualRangePage extends StatefulWidget {
  const ManualRangePage({
    super.key,
    required this.pdfName,
    this.bookId,
    this.localPath,
    this.coverPath,
  });

  final String? bookId;
  final String pdfName;
  final String? localPath;
  final String? coverPath;

  @override
  State<ManualRangePage> createState() => _ManualRangePageState();
}

class _ManualRangePageState extends State<ManualRangePage> {
  late final TextEditingController _fromController;
  late final TextEditingController _toController;
  late final TextEditingController _titleController;
  final _ranges = <PageRangeDraft>[];

  @override
  void initState() {
    super.initState();
    _fromController = TextEditingController(text: '1');
    _toController = TextEditingController();
    _titleController = TextEditingController();
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  int get _from => int.tryParse(_fromController.text) ?? 0;
  int get _to => int.tryParse(_toController.text) ?? 0;
  int get _total => (_to >= _from && _from > 0) ? (_to - _from + 1) : 0;

  bool _addCurrentRange({required bool requireValid}) {
    if (_total <= 0) {
      if (requireValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid page range.')),
        );
      }
      return false;
    }

    setState(() {
      _ranges.add(
        PageRangeDraft(
          fromPage: _from,
          toPage: _to,
          title: _titleController.text.trim(),
        ),
      );
      _fromController.text = '${_to + 1}';
      _toController.clear();
      _titleController.clear();
    });
    return true;
  }

  Future<void> _createSessions() async {
    final drafts = [..._ranges];
    if (_total > 0) {
      drafts.add(
        PageRangeDraft(
          fromPage: _from,
          toPage: _to,
          title: _titleController.text.trim(),
        ),
      );
    }

    if (drafts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one valid page range.')),
      );
      return;
    }

    final bookId = widget.bookId?.isNotEmpty == true
        ? widget.bookId!
        : DateTime.now().microsecondsSinceEpoch.toString();
    final now = DateTime.now();
    final book = Book(
      id: bookId,
      title: Book.titleFromPdfName(widget.pdfName),
      pdfName: widget.pdfName,
      sourcePdfPath: widget.localPath ?? '',
      coverPath: widget.coverPath,
      createdAt: now,
      updatedAt: now,
    );

    final sessions = [
      for (final draft in drafts)
        ReadingSession(
          id: '${DateTime.now().microsecondsSinceEpoch}_${draft.fromPage}',
          title: draft.title.isEmpty
              ? 'Pages ${draft.fromPage}–${draft.toPage}'
              : draft.title,
          pdfName: widget.pdfName,
          fromPage: draft.fromPage,
          toPage: draft.toPage,
          updatedAt: now,
          progress: 0,
          localPath: widget.localPath,
          bookId: bookId,
        ),
    ];

    await context.read<BooksCubit>().addBookWithParts(
          book: book,
          parts: sessions,
        );
    if (!mounted) return;
    context.go('/book/$bookId');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FolioColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Set Range',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    widget.pdfName,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: FolioColors.textPrimary,
                    ),
                  ),
                  if (_ranges.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    for (var i = 0; i < _ranges.length; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: FolioColors.surface,
                          borderRadius:
                              BorderRadius.circular(FolioColors.radiusCard),
                          border: Border.all(color: FolioColors.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${_ranges[i].title.isEmpty ? 'Range ${i + 1}' : _ranges[i].title} · pp. ${_ranges[i].fromPage}–${_ranges[i].toPage}',
                                style: GoogleFonts.inter(fontSize: 13),
                              ),
                            ),
                            IconButton(
                              onPressed: () =>
                                  setState(() => _ranges.removeAt(i)),
                              icon: const Icon(Icons.close, size: 18),
                              color: FolioColors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: FolioColors.surface,
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
                              child: _PageField(
                                label: 'From page',
                                controller: _fromController,
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _PageField(
                                label: 'To page',
                                controller: _toController,
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Total: $_total pages',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: FolioColors.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Session title (optional)',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: FolioColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleController,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: FolioColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Chapter 1...',
                      hintStyle: GoogleFonts.inter(
                        color: FolioColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: [
                  FolioPrimaryButton(
                    label: _ranges.isEmpty
                        ? 'Create Session'
                        : 'Create ${_ranges.length + (_total > 0 ? 1 : 0)} Sessions',
                    onPressed: _createSessions,
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: FolioColors.border),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => _addCurrentRange(requireValid: true),
                    child: Text(
                      '+ Add another range',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: FolioColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageField extends StatelessWidget {
  const _PageField({
    required this.label,
    required this.controller,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: FolioColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: onChanged,
          style: GoogleFonts.inter(
            fontSize: 16,
            color: FolioColors.textPrimary,
          ),
          decoration: const InputDecoration(
            filled: true,
            fillColor: FolioColors.surfaceElevated,
          ),
        ),
      ],
    );
  }
}
