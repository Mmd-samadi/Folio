import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:nexus_chat/features/chat/data/chat_history_builder.dart';
import 'package:nexus_chat/features/chat/domain/message_model.dart';

void main() {
  group('buildGeminiContents', () {
    test('returns only the new user message for empty history', () {
      final contents = buildGeminiContents(const [], 'Hello');

      expect(contents, hasLength(1));
      expect(contents.first.role, 'user');
      expect(contents.first.parts.single, isA<TextPart>());
      expect((contents.first.parts.single as TextPart).text, 'Hello');
    });

    test('includes complete pairs and excludes orphaned user messages', () {
      final history = [
        MessageModel(
          id: '1',
          content: 'first question',
          role: MessageRole.user,
          timestamp: DateTime(2024),
        ),
        MessageModel(
          id: '2',
          content: 'first answer',
          role: MessageRole.assistant,
          timestamp: DateTime(2024),
        ),
        MessageModel(
          id: '3',
          content: 'failed question',
          role: MessageRole.user,
          timestamp: DateTime(2024),
        ),
      ];

      final contents = buildGeminiContents(history, 'new question');

      expect(contents, hasLength(3));
      expect(contents[0].role, 'user');
      expect((contents[0].parts.single as TextPart).text, 'first question');
      expect(contents[1].role, 'model');
      expect((contents[1].parts.single as TextPart).text, 'first answer');
      expect(contents[2].role, 'user');
      expect((contents[2].parts.single as TextPart).text, 'new question');
    });

    test('skips consecutive user messages without assistant replies', () {
      final history = [
        MessageModel(
          id: '1',
          content: 'orphan one',
          role: MessageRole.user,
          timestamp: DateTime(2024),
        ),
        MessageModel(
          id: '2',
          content: 'orphan two',
          role: MessageRole.user,
          timestamp: DateTime(2024),
        ),
      ];

      final contents = buildGeminiContents(history, 'latest question');

      expect(contents, hasLength(1));
      expect((contents.single.parts.single as TextPart).text, 'latest question');
    });
  });
}
