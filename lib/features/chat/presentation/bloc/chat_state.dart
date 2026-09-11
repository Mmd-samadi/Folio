import 'package:equatable/equatable.dart';
import 'package:folio/features/chat/domain/message_model.dart';

enum ChatStatus { initial, loading, success, failure }

class ChatState extends Equatable {
  const ChatState({
    this.messages = const [],
    this.status = ChatStatus.initial,
    this.isTyping = false,
    this.errorMessage,
    this.pendingMessage,
  });

  final List<MessageModel> messages;
  final ChatStatus status;
  final bool isTyping;
  final String? errorMessage;
  final String? pendingMessage;

  ChatState copyWith({
    List<MessageModel>? messages,
    ChatStatus? status,
    bool? isTyping,
    String? errorMessage,
    String? pendingMessage,
    bool clearError = false,
    bool clearPending = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      status: status ?? this.status,
      isTyping: isTyping ?? this.isTyping,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      pendingMessage:
          clearPending ? null : pendingMessage ?? this.pendingMessage,
    );
  }

  @override
  List<Object?> get props =>
      [messages, status, isTyping, errorMessage, pendingMessage];
}
