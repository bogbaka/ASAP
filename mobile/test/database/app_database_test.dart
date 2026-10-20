import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:asap/database/app_database.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    // Create a fresh in-memory database for each test.
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    // Close the database after each test.
    await database.close();
  });

  test('saves and retrieves a message', () async {
    // Arrange: create a conversation.
    await database.into(database.conversations).insert(
          ConversationsCompanion.insert(
            id: 'conversation-1',
            contactName: 'Amaka',
          ),
        );

    // Act: save a message in that conversation.
    await database.into(database.messages).insert(
          MessagesCompanion.insert(
            conversationId: 'conversation-1',
            content: 'Hello from ASAP!',
            isOutgoing: true,
          ),
        );

    // Retrieve the saved messages.
    final messages = await database.select(database.messages).get();

    // Assert: verify that the message was saved correctly.
    expect(messages, hasLength(1));
    expect(messages.first.conversationId, 'conversation-1');
    expect(messages.first.content, 'Hello from ASAP!');
    expect(messages.first.isOutgoing, isTrue);
  });

  test('stores different conversations separately', () async {
    await database.into(database.conversations).insert(
          ConversationsCompanion.insert(
            id: 'conversation-1',
            contactName: 'Amaka',
          ),
        );

    await database.into(database.conversations).insert(
          ConversationsCompanion.insert(
            id: 'conversation-2',
            contactName: 'Daniel',
          ),
        );

    final conversations =
        await database.select(database.conversations).get();

    expect(conversations, hasLength(2));
    expect(
      conversations.map((conversation) => conversation.contactName),
      containsAll(['Amaka', 'Daniel']),
    );
  });
}