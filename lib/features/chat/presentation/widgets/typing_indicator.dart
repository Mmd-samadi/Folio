import 'package:flutter/material.dart';
import 'package:nexus_chat/core/theme/app_theme.dart';

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dotColor = isDark
        ? theme.colorScheme.onSurfaceVariant
        : AppTheme.assistantBubbleLight.withValues(alpha: 0.9);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark
              ? AppTheme.assistantBubbleDark
              : AppTheme.assistantBubbleLight,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
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
                final opacity = (value < 0.5 ? value * 2 : (1 - value) * 2)
                    .clamp(0.3, 1.0);

                return Container(
                  width: 8,
                  height: 8,
                  margin: EdgeInsets.only(left: index == 0 ? 0 : 6),
                  decoration: BoxDecoration(
                    color: dotColor.withValues(alpha: opacity),
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
