import 'package:equatable/equatable.dart';

enum MessageRole { user, assistant }

class MessageModel extends Equatable {
  const MessageModel({
    required this.id,
    required this.content,
    required this.role,
    required this.timestamp,
  });

  final String id;
  final String content;
  final MessageRole role;
  final DateTime timestamp;

  bool get isUser => role == MessageRole.user;

  @override
  List<Object?> get props => [id, content, role, timestamp];
}
