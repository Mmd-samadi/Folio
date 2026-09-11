import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:folio/core/device/device_resource_sampler.dart';
import 'package:folio/core/theme/folio_colors.dart';
import 'package:folio/features/ai/presentation/cubit/on_device_load_cubit.dart';

/// Compact overlay shown while on-device download/inference is active.
class OnDeviceResourceBanner extends StatelessWidget {
  const OnDeviceResourceBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnDeviceLoadCubit, OnDeviceLoadState?>(
      builder: (context, state) {
        // Download progress is shown by the system notification; keep the
        // overlay only for inference (CPU/RAM pressure while generating).
        if (state == null || state.kind == OnDeviceLoadKind.download) {
          return const SizedBox.shrink();
        }
        final sample = state.sample;
        final usedFrac = sample.deviceUsedFraction;
        final lowMem = usedFrac != null && usedFrac >= 0.85;
        final appRam = DeviceResourceSample.formatBytes(sample.appRssBytes);
        final deviceLine = () {
          final total = sample.deviceTotalBytes;
          final avail = sample.deviceAvailBytes;
          if (total == null || avail == null) return null;
          final used = total - avail;
          return '${DeviceResourceSample.formatBytes(used)} / '
              '${DeviceResourceSample.formatBytes(total)} device';
        }();

        return Material(
          color: Colors.transparent,
          child: SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: FolioColors.surfaceElevated,
                    borderRadius:
                        BorderRadius.circular(FolioColors.radiusCard),
                    border: Border.all(
                      color: lowMem
                          ? FolioColors.warningBorder
                          : FolioColors.border,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: FolioColors.accent,
                              backgroundColor: FolioColors.border,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              state.statusLabel,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: FolioColors.textPrimary,
                              ),
                            ),
                          ),
                          if (state.downloadProgress != null)
                            Text(
                              '${state.downloadProgress}%',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: FolioColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        deviceLine == null
                            ? 'App RAM $appRam'
                            : 'App RAM $appRam · $deviceLine',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: lowMem
                              ? FolioColors.warningText
                              : FolioColors.textSecondary,
                        ),
                      ),
                      if (usedFrac != null) ...[
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: usedFrac,
                            minHeight: 3,
                            backgroundColor: FolioColors.border,
                            color: lowMem
                                ? FolioColors.warningBorder
                                : FolioColors.accent,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
