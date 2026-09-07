import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nexus_chat/core/constants/app_constants.dart';
import 'package:nexus_chat/core/theme/folio_colors.dart';
import 'package:nexus_chat/core/widgets/folio_buttons.dart';
import 'package:nexus_chat/features/ai/data/local_gemma_service.dart';
import 'package:nexus_chat/features/ai/domain/folio_ai_provider.dart';
import 'package:nexus_chat/features/settings/presentation/cubit/settings_cubit.dart';

bool folioHasEffectiveApiKey(BuildContext context) {
  final fromSettings = context.read<SettingsCubit>().state.apiKey.trim();
  if (fromSettings.isNotEmpty && fromSettings != 'your_key_here') {
    return true;
  }
  final fromEnv = dotenv.env[AppConstants.apiKeyEnv]?.trim() ?? '';
  return fromEnv.isNotEmpty && fromEnv != 'your_key_here';
}

/// Ensures the selected AI backend is ready (Gemini key or on-device model).
Future<bool> ensureFolioAiReady(BuildContext context) async {
  final settings = context.read<SettingsCubit>().state;
  if (settings.usesOnDeviceAi) {
    final local = LocalGemmaService.instance;
    if (await local.isInstalled()) return true;
    if (!context.mounted) return false;
    return showLocalModelDownloadSheet(context);
  }
  return ensureFolioApiKey(context);
}

/// Blocking sheet shown before the first AI call when no API key is set.
Future<bool> showApiKeyGateSheet(
  BuildContext context, {
  bool editing = false,
}) async {
  final controller = TextEditingController();
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    backgroundColor: FolioColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(FolioColors.radiusSheet),
      ),
    ),
    builder: (context) {
      final bottom = MediaQuery.viewInsetsOf(context).bottom;
      return Padding(
        padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FolioSheetHandle(),
            const SizedBox(height: 16),
            Text(
              editing ? 'API Key' : 'Add Gemini API key',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              editing
                  ? 'Paste a new Gemini API key. It is stored only on this device.'
                  : 'Folio needs a free Gemini API key to summarize PDFs and answer questions. Get one at aistudio.google.com.',
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.45,
                color: FolioColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Paste Gemini API key',
              ),
            ),
            const SizedBox(height: 16),
            FolioPrimaryButton(
              label: editing ? 'Save' : 'Save & continue',
              onPressed: () async {
                final key = controller.text.trim();
                if (key.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Paste an API key to continue.')),
                  );
                  return;
                }
                await context.read<SettingsCubit>().setApiKey(key);
                if (context.mounted) Navigator.pop(context, true);
              },
            ),
            const SizedBox(height: 8),
            FolioSecondaryButton(
              label: editing ? 'Cancel' : 'Not now',
              onPressed: () => Navigator.pop(context, false),
            ),
          ],
        ),
      );
    },
  );
  return saved == true;
}

/// Ensures an API key exists; shows the gate sheet when missing.
Future<bool> ensureFolioApiKey(BuildContext context) async {
  if (folioHasEffectiveApiKey(context)) return true;
  return showApiKeyGateSheet(context);
}

/// Downloads the on-device flutter_gemma model with progress.
Future<bool> showLocalModelDownloadSheet(BuildContext context) async {
  var progress = LocalGemmaService.instance.downloadProgress ?? 0;
  var error = '';
  var downloading = false;

  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: !downloading,
    enableDrag: !downloading,
    backgroundColor: FolioColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(FolioColors.radiusSheet),
      ),
    ),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          final bottom = MediaQuery.viewInsetsOf(context).bottom;
          return Padding(
            padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const FolioSheetHandle(),
                const SizedBox(height: 16),
                Text(
                  'Download on-device model',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${AppConstants.localModelLabel} runs fully offline after a '
                  'one-time download (~330 MB). No API key or quota.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.45,
                    color: FolioColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                if (downloading) ...[
                  LinearProgressIndicator(
                    value: progress <= 0 ? null : progress / 100,
                    color: FolioColors.accent,
                    backgroundColor: FolioColors.border,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    progress <= 0 ? 'Starting…' : '$progress%',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: FolioColors.textSecondary,
                    ),
                  ),
                ],
                if (error.isNotEmpty) ...[
                  Text(
                    error,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.redAccent,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                FolioPrimaryButton(
                  label: downloading ? 'Downloading…' : 'Download & continue',
                  onPressed: downloading
                      ? null
                      : () async {
                          setModalState(() {
                            downloading = true;
                            error = '';
                            progress = 0;
                          });
                          try {
                            await LocalGemmaService.instance.ensureInstalled(
                              onProgress: (p) {
                                setModalState(() => progress = p);
                              },
                            );
                            if (context.mounted) {
                              Navigator.pop(context, true);
                            }
                          } catch (e) {
                            setModalState(() {
                              downloading = false;
                              error = e.toString();
                            });
                          }
                        },
                ),
                const SizedBox(height: 8),
                FolioSecondaryButton(
                  label: 'Cancel',
                  onPressed: downloading
                      ? null
                      : () => Navigator.pop(context, false),
                ),
              ],
            ),
          );
        },
      );
    },
  );
  return saved == true;
}

String folioAiNotReadyMessage(FolioAiProvider provider) {
  if (provider == FolioAiProvider.onDevice) {
    return AppConstants.localModelMissingMessage;
  }
  return 'GEMINI_API_KEY is missing. Add it in Settings or your .env file.';
}
