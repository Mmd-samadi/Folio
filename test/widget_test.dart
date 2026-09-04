import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_chat/features/chat/domain/message_model.dart';
import 'package:nexus_chat/features/chat/presentation/widgets/message_bubble.dart';

void main() {
  testWidgets('MessageBubble renders user message', (WidgetTester tester) async {
    final message = MessageModel(
      id: '1',
      content: 'Hello Nexus',
      role: MessageRole.user,
      timestamp: DateTime(2024),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageBubble(message: message),
        ),
      ),
    );

    expect(find.text('Hello Nexus'), findsOneWidget);
  });
}
