import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:folio/core/constants/app_constants.dart';
import 'package:folio/core/theme/theme_cubit.dart';
import 'package:folio/features/chat/data/gemini_repository.dart';
import 'package:folio/features/chat/presentation/bloc/chat_bloc.dart';
import 'package:folio/features/chat/presentation/bloc/chat_event.dart';
import 'package:folio/features/chat/presentation/bloc/chat_state.dart';
import 'package:folio/features/chat/presentation/widgets/chat_input.dart';
import 'package:folio/features/chat/presentation/widgets/message_bubble.dart';
import 'package:folio/features/chat/presentation/widgets/typing_indicator.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ChatBloc(repository: GeminiRepository()),
      child: BlocConsumer<ChatBloc, ChatState>(
        listenWhen: (previous, current) =>
            previous.messages.length != current.messages.length ||
            previous.isTyping != current.isTyping ||
            previous.status != current.status,
        listener: (context, state) {
          _scrollToBottom();

          if (state.status == ChatStatus.failure &&
              state.errorMessage != null) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage!),
                  action: state.pendingMessage != null
                      ? SnackBarAction(
                          label: 'Retry',
                          onPressed: () => context
                              .read<ChatBloc>()
                              .add(const ChatRetryRequested()),
                        )
                      : null,
                ),
              );
          }
        },
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              title: const Text(AppConstants.appTitle),
              actions: [
                BlocBuilder<ThemeCubit, ThemeMode>(
                  builder: (context, themeMode) {
                    final isDark = themeMode == ThemeMode.dark ||
                        (themeMode == ThemeMode.system &&
                            MediaQuery.platformBrightnessOf(context) ==
                                Brightness.dark);

                    return IconButton(
                      tooltip: 'Toggle theme',
                      onPressed: () => context.read<ThemeCubit>().toggleTheme(),
                      icon: Icon(
                        isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                      ),
                    );
                  },
                ),
              ],
            ),
            body: Column(
              children: [
                if (state.status == ChatStatus.failure &&
                    state.errorMessage != null)
                  MaterialBanner(
                    content: Text(state.errorMessage!),
                    leading: const Icon(Icons.wifi_off_rounded),
                    actions: [
                      TextButton(
                        onPressed: () => context
                            .read<ChatBloc>()
                            .add(const ChatRetryRequested()),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                Expanded(
                  child: state.messages.isEmpty && !state.isTyping
                      ? Center(
                          child: Text(
                            'Start a conversation with Folio',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          itemCount:
                              state.messages.length + (state.isTyping ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= state.messages.length) {
                              return const TypingIndicator();
                            }

                            return MessageBubble(
                              message: state.messages[index],
                            );
                          },
                        ),
                ),
                ChatInput(
                  enabled: !state.isTyping,
                  onSend: (text) =>
                      context.read<ChatBloc>().add(ChatMessageSent(text)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
