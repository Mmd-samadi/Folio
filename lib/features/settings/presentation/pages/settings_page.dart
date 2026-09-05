import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nexus_chat/core/constants/app_constants.dart';
import 'package:nexus_chat/core/theme/folio_colors.dart';
import 'package:nexus_chat/features/settings/domain/folio_settings.dart';
import 'package:nexus_chat/features/settings/presentation/cubit/settings_cubit.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

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
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
    final controller = TextEditingController();
    final key = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FolioColors.surface,
        title: Text(
          'API Key',
          style: GoogleFonts.inter(color: FolioColors.textPrimary),
        ),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(
            hintText: 'Paste Gemini API key',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(
              'Save',
              style: GoogleFonts.inter(color: FolioColors.accent),
            ),
          ),
        ],
      ),
    );
    if (key != null && key.isNotEmpty && context.mounted) {
      await context.read<SettingsCubit>().setApiKey(key);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('API key saved.')),
        );
      }
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
          return ListView(
            children: [
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
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: FolioColors.textSecondary,
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
