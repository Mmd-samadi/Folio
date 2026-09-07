import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nexus_chat/core/theme/folio_colors.dart';
import 'package:nexus_chat/core/widgets/folio_buttons.dart';

/// Skeleton placeholders for summary loading state.
class FolioSummarySkeleton extends StatelessWidget {
  const FolioSummarySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      children: [
        Text(
          'Generating summary…',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: FolioColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < 5; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          _SkeletonBullet(widthFactor: i.isEven ? 1.0 : 0.72),
        ],
      ],
    );
  }
}

class _SkeletonBullet extends StatelessWidget {
  const _SkeletonBullet({required this.widthFactor});

  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 6),
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: FolioColors.border,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _bar(widthFactor),
              const SizedBox(height: 8),
              _bar(widthFactor * 0.85),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bar(double factor) {
    return FractionallySizedBox(
      widthFactor: factor.clamp(0.4, 1.0),
      alignment: Alignment.centerLeft,
      child: Container(
        height: 12,
        decoration: BoxDecoration(
          color: FolioColors.surfaceElevated,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

/// Animated three-dot typing indicator for Ask Folio chat.
class FolioTypingIndicator extends StatefulWidget {
  const FolioTypingIndicator({super.key});

  @override
  State<FolioTypingIndicator> createState() => _FolioTypingIndicatorState();
}

class _FolioTypingIndicatorState extends State<FolioTypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: FolioColors.surfaceElevated,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
            bottomRight: Radius.circular(12),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            return AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final delay = index * 0.2;
                final value = (_controller.value - delay).clamp(0.0, 1.0);
                final opacity =
                    (value < 0.5 ? value * 2 : (1 - value) * 2).clamp(0.3, 1.0);
                return Container(
                  width: 7,
                  height: 7,
                  margin: EdgeInsets.only(left: index == 0 ? 0 : 5),
                  decoration: BoxDecoration(
                    color: FolioColors.textSecondary.withValues(alpha: opacity),
                    shape: BoxShape.circle,
                  ),
                );
              },
            );
          }),
        ),
      ),
    );
  }
}

/// Inline error banner with optional Retry.
class FolioInlineErrorBanner extends StatelessWidget {
  const FolioInlineErrorBanner({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel = 'Retry',
  });

  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: FolioColors.offlineBg,
        borderRadius: BorderRadius.circular(FolioColors.radiusCard),
        border: Border.all(color: FolioColors.danger),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: FolioColors.offlineText, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: FolioColors.offlineText,
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: Text(
                retryLabel,
                style: GoogleFonts.inter(
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

/// Centered summary failure / regenerate state.
class FolioSummaryErrorState extends StatelessWidget {
  const FolioSummaryErrorState({
    super.key,
    required this.message,
    required this.onRegenerate,
    this.onOpenApiKey,
  });

  final String message;
  final VoidCallback onRegenerate;
  final VoidCallback? onOpenApiKey;

  @override
  Widget build(BuildContext context) {
    final needsKey = message.toLowerCase().contains('api key') ||
        message.toLowerCase().contains('gemini_api_key') ||
        message.toLowerCase().contains('on-device model');

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
              Icons.auto_awesome_outlined,
              color: FolioColors.accent,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Couldn’t generate summary',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.45,
              color: FolioColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          FolioPrimaryButton(
            label: 'Regenerate',
            onPressed: onRegenerate,
          ),
          if (needsKey && onOpenApiKey != null) ...[
            const SizedBox(height: 12),
            FolioSecondaryButton(
              label: 'Add API key',
              onPressed: onOpenApiKey,
            ),
          ],
        ],
      ),
    );
  }
}
