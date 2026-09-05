import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nexus_chat/core/theme/folio_colors.dart';
import 'package:nexus_chat/core/widgets/folio_buttons.dart';
import 'package:nexus_chat/features/sessions/domain/reading_session.dart';
import 'package:nexus_chat/features/sessions/presentation/cubit/sessions_cubit.dart';

class ManualRangePage extends StatefulWidget {
  const ManualRangePage({
    super.key,
    required this.pdfName,
    this.localPath,
  });

  final String pdfName;
  final String? localPath;

  @override
  State<ManualRangePage> createState() => _ManualRangePageState();
}

class _ManualRangePageState extends State<ManualRangePage> {
  late final TextEditingController _fromController;
  late final TextEditingController _toController;
  late final TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _fromController = TextEditingController(text: '12');
    _toController = TextEditingController(text: '45');
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

  void _createSession() {
    if (_total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid page range.')),
      );
      return;
    }

    final title = _titleController.text.trim().isEmpty
        ? 'Pages $_from–$_to'
        : _titleController.text.trim();

    final session = ReadingSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      pdfName: widget.pdfName,
      fromPage: _from,
      toPage: _to,
      updatedAt: DateTime.now(),
      progress: 0,
      localPath: widget.localPath,
    );

    context.read<SessionsCubit>().add(session);
    context.go('/reader/${session.id}');
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
                    label: 'Create Session',
                    onPressed: _createSession,
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: FolioColors.border),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Multi-range coming in next phase.'),
                        ),
                      );
                    },
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
