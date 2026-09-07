import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nexus_chat/core/constants/app_constants.dart';
import 'package:nexus_chat/core/theme/folio_colors.dart';
import 'package:nexus_chat/features/ai/data/local_gemma_service.dart';
import 'package:nexus_chat/features/ai/domain/folio_ai_provider.dart';
import 'package:nexus_chat/features/settings/domain/folio_settings.dart';
import 'package:nexus_chat/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:nexus_chat/features/settings/presentation/widgets/api_key_gate_sheet.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool? _modelInstalled;
  bool _checkingModel = true;
  bool _downloading = false;
  int _downloadProgress = 0;

  @override
  void initState() {
    super.initState();
    _refreshModelStatus();
  }

  Future<void> _refreshModelStatus() async {
    final installed = await LocalGemmaService.instance.isInstalled();
    if (!mounted) return;
    setState(() {
      _modelInstalled = installed;
      _checkingModel = false;
    });
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
                      ? const Icon(Icons.check, color: FolioColors.accent)
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

  Future<void> _downloadModel() async {
    setState(() {
      _downloading = true;
      _downloadProgress = 0;
    });
    try {
      await LocalGemmaService.instance.ensureInstalled(
        onProgress: (p) {
          if (mounted) setState(() => _downloadProgress = p);
        },
      );
      if (!mounted) return;
      setState(() {
        _modelInstalled = true;
        _downloading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('On-device model ready.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _downloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
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
        title: const Text('Settings'),
      ),
      body: BlocBuilder<SettingsCubit, FolioSettings>(
        builder: (context, settings) {
          final modelStatus = _checkingModel
              ? 'Checking…'
              : _downloading
                  ? 'Downloading $_downloadProgress%'
                  : (_modelInstalled == true ? 'Installed' : 'Not downloaded');

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
              if (settings.usesOnDeviceAi)
                _SettingRow(
                  label: AppConstants.localModelLabel,
                  value: modelStatus,
                  trailing: (_modelInstalled != true && !_downloading)
                      ? const Icon(
                          Icons.download_outlined,
                          size: 16,
                          color: FolioColors.textSecondary,
                        )
                      : null,
                  onTap: (_modelInstalled == true || _downloading)
                      ? null
                      : _downloadModel,
                ),
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
              _SettingRow(
                label: 'Default chat scope',
                value: settings.chatScope,
                onTap: () => _pickOption(
                  context: context,
                  title: 'Default chat scope',
                  options: const ['Section', 'Full PDF'],
                  current: settings.chatScope,
                  onPicked: (v) =>
                      context.read<SettingsCubit>().setChatScope(v),
                ),
              ),
              const _SettingRow(
                label: 'Theme',
                value: 'Dark',
              ),
              if (!settings.usesOnDeviceAi)
                _SettingRow(
                  label: 'API Key',
                  value: settings.maskedApiKey,
                  trailing: const Icon(
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
          decoration: const BoxDecoration(
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
