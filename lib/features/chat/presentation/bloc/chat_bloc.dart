import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexus_chat/features/chat/data/api_exception.dart';
import 'package:nexus_chat/features/chat/data/gemini_repository.dart';
import 'package:nexus_chat/features/chat/data/network_exception.dart';
import 'package:nexus_chat/features/chat/domain/message_model.dart';
import 'package:nexus_chat/features/chat/presentation/bloc/chat_event.dart';
import 'package:nexus_chat/features/chat/presentation/bloc/chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  ChatBloc({required this.repository}) : super(const ChatState()) {
    on<ChatMessageSent>(_onMessageSent);
    on<ChatRetryRequested>(_onRetryRequested);
  }

  final GeminiRepository repository;

  Future<void> _onMessageSent(
    ChatMessageSent event,
    Emitter<ChatState> emit,
  ) async {
    final text = event.text.trim();
    if (text.isEmpty || state.isTyping) {
      return;
    }

    final userMessage = MessageModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: text,
      role: MessageRole.user,
      timestamp: DateTime.now(),
    );

    final updatedMessages = [...state.messages, userMessage];

    emit(
      state.copyWith(
        messages: updatedMessages,
        status: ChatStatus.loading,
        isTyping: true,
        clearError: true,
        pendingMessage: text,
      ),
    );

    await _fetchAssistantReply(
      emit: emit,
      history: updatedMessages,
      userMessage: text,
    );
  }

  Future<void> _onRetryRequested(
    ChatRetryRequested event,
    Emitter<ChatState> emit,
  ) async {
    final pendingMessage = state.pendingMessage;
    if (pendingMessage == null || state.isTyping) {
      return;
    }

    emit(
      state.copyWith(
        status: ChatStatus.loading,
        isTyping: true,
        clearError: true,
      ),
    );

    await _fetchAssistantReply(
      emit: emit,
      history: state.messages,
      userMessage: pendingMessage,
    );
  }

  Future<void> _fetchAssistantReply({
    required Emitter<ChatState> emit,
    required List<MessageModel> history,
    required String userMessage,
  }) async {
    try {
      final reply = await repository.sendMessage(
        history: history,
        userMessage: userMessage,
      );

      final assistantMessage = MessageModel(
        id: '${DateTime.now().millisecondsSinceEpoch}_assistant',
        content: reply.isEmpty ? 'Sorry, I could not generate a response.' : reply,
        role: MessageRole.assistant,
        timestamp: DateTime.now(),
      );

      final updatedMessages = _messagesWithUserAndAssistant(
        currentMessages: state.messages,
        userMessage: userMessage,
        assistantMessage: assistantMessage,
      );

      emit(
        state.copyWith(
          messages: updatedMessages,
          status: ChatStatus.success,
          isTyping: false,
          clearError: true,
          clearPending: true,
        ),
      );
    } on NetworkException catch (error) {
      emit(_failureState(error.message, userMessage));
    } on ApiException catch (error) {
      emit(_failureState(error.message, userMessage));
    } catch (error) {
      emit(_failureState(error.toString(), userMessage));
    }
  }

  ChatState _failureState(String errorMessage, String userMessage) {
    return state.copyWith(
      messages: _messagesWithoutPendingUser(state.messages, userMessage),
      status: ChatStatus.failure,
      isTyping: false,
      errorMessage: errorMessage,
      pendingMessage: userMessage,
    );
  }

  List<MessageModel> _messagesWithoutPendingUser(
    List<MessageModel> messages,
    String userMessage,
  ) {
    if (messages.isEmpty) {
      return messages;
    }

    final lastMessage = messages.last;
    if (lastMessage.role == MessageRole.user &&
        lastMessage.content == userMessage) {
      return messages.sublist(0, messages.length - 1);
    }

    return messages;
  }

  List<MessageModel> _messagesWithUserAndAssistant({
    required List<MessageModel> currentMessages,
    required String userMessage,
    required MessageModel assistantMessage,
  }) {
    final updatedMessages = [...currentMessages];
    final hasPendingUserMessage = updatedMessages.isNotEmpty &&
        updatedMessages.last.role == MessageRole.user &&
        updatedMessages.last.content == userMessage;

    if (!hasPendingUserMessage) {
      updatedMessages.add(
        MessageModel(
          id: '${DateTime.now().millisecondsSinceEpoch}_user',
          content: userMessage,
          role: MessageRole.user,
          timestamp: DateTime.now(),
        ),
      );
    }

    updatedMessages.add(assistantMessage);
    return updatedMessages;
  }
}
