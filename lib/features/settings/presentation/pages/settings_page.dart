import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:folio/core/constants/app_constants.dart';
import 'package:folio/core/errors/cancelled_exception.dart';
import 'package:folio/core/theme/folio_colors.dart';
import 'package:folio/features/ai/data/local_gemma_service.dart';
import 'package:folio/features/ai/data/on_device_model_catalog_service.dart';
import 'package:folio/features/ai/domain/folio_ai_provider.dart';
import 'package:folio/features/ai/domain/on_device_model.dart';
import 'package:folio/features/settings/domain/folio_settings.dart';
import 'package:folio/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:folio/features/settings/presentation/widgets/api_key_gate_sheet.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Map<String, bool> _installed = {};
  bool _checkingModel = true;
  bool _refreshingCatalog = false;
  String? _downloadingModelId;
  int _downloadProgress = 0;
  bool _cancellingDownload = false;
  OnDeviceCatalogSnapshot? _catalog;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final snapshot =
        await OnDeviceModelCatalogService.instance.ensureLoaded();
    if (!mounted) return;
    setState(() => _catalog = snapshot);
    await _refreshModelStatus();
  }

  Future<void> _refreshModelStatus() async {
    final status = await LocalGemmaService.instance.installedStatusMap();
    if (!mounted) return;
    setState(() {
      _installed = status;
      _checkingModel = false;
    });
  }

  Future<void> _refreshCatalog() async {
    if (_refreshingCatalog) return;
    setState(() => _refreshingCatalog = true);
    try {
      final snapshot = await OnDeviceModelCatalogService.instance.refresh();
      if (!mounted) return;
      setState(() => _catalog = snapshot);
      await _refreshModelStatus();
      if (!mounted) return;
      final sourceLabel = switch (snapshot.source) {
        OnDeviceCatalogSource.remote => 'Updated from network',
        OnDeviceCatalogSource.cache => 'Loaded from cache',
        OnDeviceCatalogSource.bundled => 'Using bundled catalog',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(sourceLabel)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not refresh model list: $e')),
      );
    } finally {
      if (mounted) setState(() => _refreshingCatalog = false);
    }
  }

  Future<void> _pickOption({
    required BuildContext context,
    required String title,
    required List<String> options,
    required String current,
    required ValueChanged<String> onPicked,
  }) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: FolioColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: FolioColors.textDim,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              for (final option in options)
                ListTile(
                  title: Text(
                    option,
                    style: GoogleFonts.inter(
                      color: option == current
                          ? FolioColors.accent
                          : FolioColors.textPrimary,
                      fontWeight:
                          option == current ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  trailing: option == current
                      ? Icon(Icons.check, color: FolioColors.accent)
                      : null,
                  onTap: () => Navigator.pop(context, option),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (result != null) onPicked(result);
  }

  Future<void> _editApiKey(BuildContext context) async {
    final saved = await showApiKeyGateSheet(context, editing: true);
    if (saved && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API key saved.')),
      );
    }
  }

  String _statusFor(OnDeviceModel model) {
    if (_checkingModel) return 'Checking…';
    if (_cancellingDownload && _downloadingModelId == model.id) {
      return 'Cancelling…';
    }
    if (_downloadingModelId == model.id) {
      return 'Downloading $_downloadProgress%';
    }
    if (_installed[model.id] == true) return 'Installed';
    return 'Not downloaded';
  }

  String _catalogMetaLabel(OnDeviceCatalogSnapshot? catalog) {
    if (catalog == null) return 'Loading…';
    final source = switch (catalog.source) {
      OnDeviceCatalogSource.remote => 'network',
      OnDeviceCatalogSource.cache => 'cache',
      OnDeviceCatalogSource.bundled => 'bundled',
    };
    return 'v${catalog.version} · $source';
  }

  Future<void> _onModelTap(OnDeviceModel model) async {
    if (_downloadingModelId != null) return;

    final alreadyInstalled = _installed[model.id] == true;
    if (alreadyInstalled) {
      final cubit = context.read<SettingsCubit>();
      await cubit.setOnDeviceModelId(model.id);
      try {
        await LocalGemmaService.instance.ensureInstalled(model: model);
      } catch (_) {
        // Selection still saved; activation can retry on next generate.
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${model.label} selected.')),
      );
      return;
    }

    setState(() {
      _downloadingModelId = model.id;
      _downloadProgress = 0;
      _cancellingDownload = false;
    });
    final cubit = context.read<SettingsCubit>();
    try {
      await LocalGemmaService.instance.ensureInstalled(
        model: model,
        onProgress: (p) {
          if (mounted) setState(() => _downloadProgress = p);
        },
      );
      await cubit.setOnDeviceModelId(model.id);
      if (!mounted) return;
      setState(() {
        _installed = {..._installed, model.id: true};
        _downloadingModelId = null;
        _cancellingDownload = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${model.label} ready.')),
      );
    } on CancelledException {
      if (!mounted) return;
      setState(() {
        _downloadingModelId = null;
        _cancellingDownload = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download cancelled.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _downloadingModelId = null;
        _cancellingDownload = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  void _cancelDownload() {
    LocalGemmaService.instance.cancelDownload();
    if (_downloadingModelId != null && mounted) {
      setState(() => _cancellingDownload = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final models = _catalog?.models ?? OnDeviceModels.catalog;

    return Scaffold(
      backgroundColor: FolioColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Settings'),
      ),
      body: BlocBuilder<SettingsCubit, FolioSettings>(
        builder: (context, settings) {
          return ListView(
            children: [
              _SettingRow(
                label: 'AI provider',
                value: settings.aiProvider.label,
                onTap: () => _pickOption(
                  context: context,
                  title: 'AI provider',
                  options: FolioAiProvider.values.map((e) => e.label).toList(),
                  current: settings.aiProvider.label,
                  onPicked: (v) {
                    final provider = FolioAiProvider.values.firstWhere(
                      (e) => e.label == v,
                      orElse: () => FolioAiProvider.onDevice,
                    );
                    context.read<SettingsCubit>().setAiProvider(provider);
                  },
                ),
              ),
              if (settings.usesOnDeviceAi) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'On-device models',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: FolioColors.textSecondary,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      Text(
                        _catalogMetaLabel(_catalog),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: FolioColors.textDim,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Refresh model list',
                        onPressed:
                            _refreshingCatalog ? null : _refreshCatalog,
                        icon: _refreshingCatalog
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh, size: 18),
                        color: FolioColors.textSecondary,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
                if (models.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Text(
                      'No models available yet.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: FolioColors.textSecondary,
                      ),
                    ),
                  )
                else
                  for (final model in models)
                    _ModelRow(
                      model: model,
                      selected: settings.onDeviceModelId == model.id,
                      status: _statusFor(model),
                      busy: _downloadingModelId != null,
                      downloading: _downloadingModelId == model.id,
                      cancelling: _cancellingDownload &&
                          _downloadingModelId == model.id,
                      onTap: () => _onModelTap(model),
                      onCancel: _cancelDownload,
                    ),
              ],
              _SettingRow(
                label: 'Default format',
                value: settings.format,
                onTap: () => _pickOption(
                  context: context,
                  title: 'Default format',
                  options: const ['Bullet', 'Paragraph', 'Q&A'],
                  current: settings.format,
                  onPicked: (v) => context.read<SettingsCubit>().setFormat(v),
                ),
              ),
              _SettingRow(
                label: 'Default length',
                value: settings.length,
                onTap: () => _pickOption(
                  context: context,
                  title: 'Default length',
                  options: const ['Short', 'Medium', 'Long'],
                  current: settings.length,
                  onPicked: (v) => context.read<SettingsCubit>().setLength(v),
                ),
              ),
              if (!settings.usesOnDeviceAi)
                _SettingRow(
                  label: 'API Key',
                  value: settings.maskedApiKey,
                  trailing: Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: FolioColors.textSecondary,
                  ),
                  onTap: () => _editApiKey(context),
                ),
              const _SettingRow(
                label: 'About',
                value: AppConstants.appVersion,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ModelRow extends StatelessWidget {
  const _ModelRow({
    required this.model,
    required this.selected,
    required this.status,
    required this.busy,
    required this.downloading,
    required this.cancelling,
    required this.onTap,
    required this.onCancel,
  });

  final OnDeviceModel model;
  final bool selected;
  final String status;
  final bool busy;
  final bool downloading;
  final bool cancelling;
  final VoidCallback onTap;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final installed = status == 'Installed';
    return Material(
      color: FolioColors.surface,
      child: InkWell(
        onTap: busy ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: FolioColors.border),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            model.label,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? FolioColors.accent
                                  : FolioColors.textPrimary,
                            ),
                          ),
                        ),
                        if (selected) ...[
                          const SizedBox(width: 8),
                          Text(
                            'Active',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: FolioColors.accent,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${model.resolvedDeviceTierLabel} · ${model.sizeLabel} · ${model.description}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        height: 1.35,
                        color: FolioColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    status,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: FolioColors.textSecondary,
                    ),
                  ),
                  if (downloading && !cancelling) ...[
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: onCancel,
                      style: TextButton.styleFrom(
                        foregroundColor: FolioColors.danger,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ] else if (!installed && !downloading) ...[
                    const SizedBox(height: 4),
                    Icon(
                      Icons.download_outlined,
                      size: 16,
                      color: FolioColors.textSecondary,
                    ),
                  ],
                  if (selected && installed)
                    Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Icon(
                        Icons.check,
                        size: 16,
                        color: FolioColors.accent,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.label,
    required this.value,
    this.onTap,
    this.trailing,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: FolioColors.surface,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: FolioColors.border),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: FolioColors.textPrimary,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: FolioColors.textSecondary,
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
