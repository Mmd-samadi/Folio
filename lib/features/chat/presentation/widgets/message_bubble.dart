import 'package:flutter/material.dart';
import 'package:folio/core/theme/app_theme.dart';
import 'package:folio/features/chat/domain/message_model.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message});

  final MessageModel message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final backgroundColor = isUser
        ? (isDark ? AppTheme.userBubbleDark : AppTheme.userBubbleLight)
        : (isDark ? AppTheme.assistantBubbleDark : AppTheme.assistantBubbleLight);

    final textColor = isUser
        ? Colors.white
        : theme.colorScheme.onSurface;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: Text(
          message.content,
          style: theme.textTheme.bodyLarge?.copyWith(color: textColor),
        ),
      ),
    );
  }
}
