import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:folio/features/chat/domain/message_model.dart';

List<Content> buildGeminiContents(
  List<MessageModel> history,
  String userMessage,
) {
  final contents = <Content>[];

  for (var index = 0; index < history.length; index++) {
    final message = history[index];
    if (message.role != MessageRole.user || message.content.isEmpty) {
      continue;
    }

    final hasAssistantReply = index + 1 < history.length &&
        history[index + 1].role == MessageRole.assistant &&
        history[index + 1].content.isNotEmpty;

    if (!hasAssistantReply) {
      continue;
    }

    contents.add(_toContent(message));
    contents.add(_toContent(history[index + 1]));
    index++;
  }

  contents.add(Content.text(userMessage));
  return contents;
}

Content _toContent(MessageModel message) {
  return Content(
    message.role == MessageRole.user ? 'user' : 'model',
    [TextPart(message.content)],
  );
}
