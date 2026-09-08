import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nexus_chat/core/theme/folio_colors.dart';
import 'package:nexus_chat/core/widgets/folio_buttons.dart';
import 'package:nexus_chat/features/chat/data/api_exception.dart';
import 'package:nexus_chat/features/import/data/offline_section_detector.dart';
import 'package:nexus_chat/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:nexus_chat/features/settings/presentation/widgets/api_key_gate_sheet.dart';
import 'package:pdfrx/pdfrx.dart';

/// Pick a page range (or entire book) while previewing the PDF, then detect headings.
class TopicDetectPage extends StatefulWidget {
  const TopicDetectPage({
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
  State<TopicDetectPage> createState() => _TopicDetectPageState();
}

class _TopicDetectPageState extends State<TopicDetectPage> {
  late final TextEditingController _fromController;
  late final TextEditingController _toController;
  final _pdfController = PdfViewerController();
  var _loading = false;
  var _defaultsApplied = false;
  var _currentPage = 1;
  var _pageCount = 0;
  var _loadingStatus = 'Scanning headings…';
  String? _error;

  @override
  void initState() {
    super.initState();
    _fromController = TextEditingController(text: '1');
    _toController = TextEditingController();
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  int get _from => int.tryParse(_fromController.text) ?? 0;
  int get _to => int.tryParse(_toController.text) ?? 0;
  int get _windowPages =>
      (_to >= _from && _from > 0) ? (_to - _from + 1) : 0;

  bool get _valid {
    if (_windowPages <= 0) return false;
    if (_pageCount > 0 && (_from > _pageCount || _to > _pageCount)) {
      return false;
    }
    return true;
  }

  String get _rangeHint {
    if (_windowPages <= 0) return 'Enter a valid range';
    if (_pageCount > 0 && (_from > _pageCount || _to > _pageCount)) {
      return 'Pages must be within 1–$_pageCount';
    }
    if (_pageCount > 0 && _from == 1 && _to == _pageCount) {
      return 'Entire book · $_windowPages page${_windowPages == 1 ? '' : 's'}';
    }
    return 'Range: $_windowPages page${_windowPages == 1 ? '' : 's'}';
  }

  void _applyDefaultsIfNeeded(int pageCount) {
    if (_defaultsApplied || pageCount <= 0) return;
    _defaultsApplied = true;
    _fromController.text = '1';
    _toController.text = '$pageCount';
  }

  void _onPageChanged(int? pageNumber) {
    final total = _pdfController.pageCount;
    setState(() {
      _currentPage = pageNumber ?? _currentPage;
      if (total > 0) {
        _pageCount = total;
        _applyDefaultsIfNeeded(total);
      }
    });
  }

  void _goPrev() {
    if (_currentPage <= 1) return;
    _pdfController.goToPage(pageNumber: _currentPage - 1);
  }

  void _goNext() {
    if (_pageCount > 0 && _currentPage >= _pageCount) return;
    _pdfController.goToPage(pageNumber: _currentPage + 1);
  }

  Future<void> _jumpToPage() async {
    final controller = TextEditingController(text: '$_currentPage');
    final page = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: FolioColors.surface,
          title: Text(
            'Go to page',
            style: GoogleFonts.inter(color: FolioColors.textPrimary),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              hintText: _pageCount > 0 ? '1–$_pageCount' : 'Page number',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final value = int.tryParse(controller.text.trim());
                Navigator.pop(context, value);
              },
              child: Text(
                'Go',
                style: GoogleFonts.inter(color: FolioColors.accent),
              ),
            ),
          ],
        );
      },
    );
    if (page == null || !mounted) return;
    final max = _pageCount > 0 ? _pageCount : page;
    final clamped = page.clamp(1, max);
    _pdfController.goToPage(pageNumber: clamped);
  }

  void _setFromCurrent() {
    setState(() {
      _fromController.text = '$_currentPage';
      _error = null;
      if (_to > 0 && _to < _currentPage) {
        final capped = _pageCount > 0 ? _pageCount : _currentPage;
        _toController.text = '$capped';
      }
    });
  }

  void _setToCurrent() {
    setState(() {
      _toController.text = '$_currentPage';
      _error = null;
      if (_from <= 0 || _from > _currentPage) {
        _fromController.text = '1';
      }
    });
  }

  void _useEntireBook() {
    if (_pageCount <= 0) return;
    setState(() {
      _fromController.text = '1';
      _toController.text = '$_pageCount';
      _error = null;
    });
  }

  Future<void> _detect() async {
    if (!_valid) {
      setState(() {
        _error = _windowPages <= 0
            ? 'Enter a valid page range.'
            : 'Pages must be within the PDF.';
      });
      return;
    }

    final path = widget.localPath;
    if (path == null || path.isEmpty) {
      setState(() => _error = 'PDF file is missing. Import again.');
      return;
    }

    setState(() {
      _loading = true;
      _loadingStatus = 'Scanning for table of contents…';
      _error = null;
    });

    try {
      final result = await const OfflineSectionDetector().detect(
        pdfPath: path,
        fromPage: _from,
        toPage: _to,
        onStatus: (status) {
          if (!mounted) return;
          setState(() => _loadingStatus = status);
        },
        ensureAiReady: () async {
          if (!mounted) return false;
          return ensureFolioAiReady(context);
        },
        aiProvider: context.read<SettingsCubit>().state.aiProvider,
        onDeviceModel: context.read<SettingsCubit>().state.onDeviceModel,
        apiKey: context.read<SettingsCubit>().state.apiKey,
      );
      if (!mounted) return;

      await context.push(
        '/chapters-found',
        extra: {
          'bookId': widget.bookId,
          'pdfName': widget.pdfName,
          'localPath': widget.localPath,
          'coverPath': widget.coverPath,
          'chapters': result.topics,
          'windowFrom': result.fromPage,
          'windowTo': result.toPage,
          'notes': result.notes,
        },
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } on StateError catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Topic detection failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.localPath;
    final hasPdf = path != null && path.isNotEmpty && File(path).existsSync();

    return Scaffold(
      backgroundColor: FolioColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _loading ? null : () => context.pop(),
        ),
        title: Text(
          widget.pdfName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: hasPdf
                      ? _PdfPreview(
                          path: path,
                          controller: _pdfController,
                          currentPage: _currentPage,
                          pageCount: _pageCount,
                          onPageChanged: _onPageChanged,
                          onPrev: _goPrev,
                          onNext: _goNext,
                          onJump: _jumpToPage,
                        )
                      : const _MissingPdfState(),
                ),
                _RangePanel(
                  fromController: _fromController,
                  toController: _toController,
                  loading: _loading,
                  valid: _valid,
                  rangeHint: _rangeHint,
                  error: _error,
                  currentPage: _currentPage,
                  pageCount: _pageCount,
                  onChanged: () => setState(() => _error = null),
                  onSetFrom: _setFromCurrent,
                  onSetTo: _setToCurrent,
                  onEntireBook: _useEntireBook,
                  onDetect: _detect,
                  onSkipManual: () {
                    context.pushReplacement(
                      '/manual-range',
                      extra: {
                        'bookId': widget.bookId,
                        'pdfName': widget.pdfName,
                        'localPath': widget.localPath,
                        'coverPath': widget.coverPath,
                      },
                    );
                  },
                ),
              ],
            ),
            if (_loading)
              Positioned.fill(
                child: _ScanningOverlay(status: _loadingStatus),
              ),
          ],
        ),
      ),
    );
  }
}

class _ScanningOverlay extends StatelessWidget {
  const _ScanningOverlay({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: FolioColors.background.withValues(alpha: 0.92),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: FolioColors.accent,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              status,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: FolioColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'This can take a moment for large books.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: FolioColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PdfPreview extends StatelessWidget {
  const _PdfPreview({
    required this.path,
    required this.controller,
    required this.currentPage,
    required this.pageCount,
    required this.onPageChanged,
    required this.onPrev,
    required this.onNext,
    required this.onJump,
  });

  final String path;
  final PdfViewerController controller;
  final int currentPage;
  final int pageCount;
  final ValueChanged<int?> onPageChanged;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onJump;

  @override
  Widget build(BuildContext context) {
    final label = pageCount > 0
        ? 'Page $currentPage / $pageCount'
        : 'Page $currentPage';

    return Column(
      children: [
        Expanded(
          child: PdfViewer.file(
            path,
            controller: controller,
            initialPageNumber: 1,
            params: PdfViewerParams(
              backgroundColor: FolioColors.background,
              onPageChanged: onPageChanged,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: FolioColors.surface,
              borderRadius: BorderRadius.circular(FolioColors.radiusCard),
              border: Border.all(color: FolioColors.border),
            ),
            child: Row(
              children: [
                _NavBtn(
                  icon: Icons.chevron_left,
                  onTap: currentPage <= 1 ? null : onPrev,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: onJump,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _NavBtn(
                  icon: Icons.chevron_right,
                  onTap: pageCount > 0 && currentPage >= pageCount
                      ? null
                      : onNext,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NavBtn extends StatelessWidget {
  const _NavBtn({required this.icon, this.onTap});

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
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            icon,
            color: onTap == null
                ? FolioColors.textDim
                : FolioColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _MissingPdfState extends StatelessWidget {
  const _MissingPdfState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'PDF file is missing. Import again to preview pages.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: FolioColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _RangePanel extends StatelessWidget {
  const _RangePanel({
    required this.fromController,
    required this.toController,
    required this.loading,
    required this.valid,
    required this.rangeHint,
    required this.error,
    required this.currentPage,
    required this.pageCount,
    required this.onChanged,
    required this.onSetFrom,
    required this.onSetTo,
    required this.onEntireBook,
    required this.onDetect,
    required this.onSkipManual,
  });

  final TextEditingController fromController;
  final TextEditingController toController;
  final bool loading;
  final bool valid;
  final String rangeHint;
  final String? error;
  final int currentPage;
  final int pageCount;
  final VoidCallback onChanged;
  final VoidCallback onSetFrom;
  final VoidCallback onSetTo;
  final VoidCallback onEntireBook;
  final VoidCallback onDetect;
  final VoidCallback onSkipManual;

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
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: FolioColors.textDim,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Detect headings',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose any page range, or scan the entire book. Skip cover/TOC if you want.',
            style: GoogleFonts.inter(
              fontSize: 12,
              height: 1.4,
              color: FolioColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _PageField(
                  label: 'From page',
                  controller: fromController,
                  enabled: !loading,
                  onChanged: (_) => onChanged(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PageField(
                  label: 'To page',
                  controller: toController,
                  enabled: !loading,
                  onChanged: (_) => onChanged(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            rangeHint,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: valid ? FolioColors.accent : FolioColors.danger,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuickChip(
                label: 'From = $currentPage',
                onTap: loading ? null : onSetFrom,
              ),
              _QuickChip(
                label: 'To = $currentPage',
                onTap: loading ? null : onSetTo,
              ),
              _QuickChip(
                label: pageCount > 0 ? 'Entire book (1–$pageCount)' : 'Entire book',
                onTap: loading || pageCount <= 0 ? null : onEntireBook,
              ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: FolioColors.offlineBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: FolioColors.danger),
              ),
              child: Text(
                error!,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: FolioColors.offlineText,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          FolioPrimaryButton(
            label: loading ? 'Scanning…' : 'Detect headings',
            onPressed: loading || !valid ? null : onDetect,
          ),
          TextButton(
            onPressed: loading ? null : onSkipManual,
            child: Text(
              'Skip — set ranges manually',
              style: GoogleFonts.inter(
                fontSize: 13,
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

class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: FolioColors.surfaceElevated,
      borderRadius: BorderRadius.circular(FolioColors.radiusButton),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(FolioColors.radiusButton),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(FolioColors.radiusButton),
            border: Border.all(color: FolioColors.border),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: onTap == null
                  ? FolioColors.textDim
                  : FolioColors.textPrimary,
            ),
          ),
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
    this.enabled = true,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool enabled;

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
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: enabled,
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
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }
}
