import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moonbase_skeleton/services/chat_repository.dart';
import 'package:moonbase_skeleton/models/chat_message.dart';
import 'package:moonbase_skeleton/models/enums.dart';

void main() {
  group('SpChatRepository', () {
    late SpChatRepository repository;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      repository = SpChatRepository();
    });

    tearDown(() async {
      await prefs.clear();
      repository.dispose();
    });

    group('sendMessage', () {
      test('should send text message', () async {
        final message = await repository.sendMessage(
          baseId: 'base_1',
          authorUserId: 'user_123',
          type: MessageType.text,
          text: 'Hello world!',
        );

        expect(message.baseId, equals('base_1'));
        expect(message.authorUserId, equals('user_123'));
        expect(message.type, equals(MessageType.text));
        expect(message.text, equals('Hello world!'));
        expect(message.createdAt, isNotNull);
        expect(message.isEdited, isFalse);
        expect(message.isDeleted, isFalse);

        // Verify it's saved to storage
        final messages = await repository.getMessages(baseId: 'base_1');
        expect(messages.length, equals(1));
        expect(messages.first.id, equals(message.id));
      });

      test('should send message with media', () async {
        final message = await repository.sendMessage(
          baseId: 'base_1',
          authorUserId: 'user_123',
          type: MessageType.media,
          text: 'Check this out!',
          mediaUrls: ['https://example.com/image1.jpg', 'https://example.com/image2.jpg'],
        );

        expect(message.media, isNotNull);
        expect(message.media!.length, equals(2));
        expect(message.media!.first.uri, equals('https://example.com/image1.jpg'));
        expect(message.media!.first.type, equals(MediaType.image));
      });

      test('should send reply message', () async {
        // Send original message
        final originalMessage = await repository.sendMessage(
          baseId: 'base_1',
          authorUserId: 'user_123',
          type: MessageType.text,
          text: 'Original message',
        );

        // Send reply
        final replyMessage = await repository.sendMessage(
          baseId: 'base_1',
          authorUserId: 'user_456',
          type: MessageType.text,
          text: 'This is a reply',
          replyToMessageId: originalMessage.id,
        );

        expect(replyMessage.replyToMessageId, equals(originalMessage.id));
      });
    });

    group('getMessages', () {
      test('should return messages for base', () async {
        // Send multiple messages
        await repository.sendMessage(
          baseId: 'base_1',
          authorUserId: 'user_123',
          type: MessageType.text,
          text: 'Message 1',
        );

        await repository.sendMessage(
          baseId: 'base_1',
          authorUserId: 'user_456',
          type: MessageType.text,
          text: 'Message 2',
        );

        await repository.sendMessage(
          baseId: 'base_2', // Different base
          authorUserId: 'user_123',
          type: MessageType.text,
          text: 'Message 3',
        );

        final messages = await repository.getMessages(baseId: 'base_1');
        expect(messages.length, equals(2));
        expect(messages.map((m) => m.text), containsAll(['Message 1', 'Message 2']));
      });

      test('should return empty list for base with no messages', () async {
        final messages = await repository.getMessages(baseId: 'empty_base');
        expect(messages, isEmpty);
      });

      test('should limit results', () async {
        // Send 5 messages
        for (int i = 1; i <= 5; i++) {
          await repository.sendMessage(
            baseId: 'base_1',
            authorUserId: 'user_123',
            type: MessageType.text,
            text: 'Message $i',
          );
        }

        final messages = await repository.getMessages(baseId: 'base_1', limit: 3);
        expect(messages.length, equals(3));
      });

      test('should sort by creation date (newest first)', () async {
        await repository.sendMessage(
          baseId: 'base_1',
          authorUserId: 'user_123',
          type: MessageType.text,
          text: 'First message',
        );

        await Future.delayed(const Duration(milliseconds: 10));

        await repository.sendMessage(
          baseId: 'base_1',
          authorUserId: 'user_123',
          type: MessageType.text,
          text: 'Second message',
        );

        final messages = await repository.getMessages(baseId: 'base_1');
        expect(messages.length, equals(2));
        expect(messages.first.text, equals('Second message'));
        expect(messages.last.text, equals('First message'));
      });
    });

    group('streamMessages', () {
      test('should stream messages for base', () async {
        final stream = repository.streamMessages(baseId: 'base_1');
        
        // Listen to stream
        final messages = <List<ChatMessage>>[];
        final subscription = stream.listen((messageList) {
          messages.add(messageList);
        });

        // Send a message
        await repository.sendMessage(
          baseId: 'base_1',
          authorUserId: 'user_123',
          type: MessageType.text,
          text: 'Streamed message',
        );

        // Wait a bit for stream to update
        await Future.delayed(const Duration(milliseconds: 100));

        expect(messages.length, greaterThan(0));
        expect(messages.last.length, equals(1));
        expect(messages.last.first.text, equals('Streamed message'));

        subscription.cancel();
      });
    });

    group('editMessage', () {
      test('should edit message', () async {
        final message = await repository.sendMessage(
          baseId: 'base_1',
          authorUserId: 'user_123',
          type: MessageType.text,
          text: 'Original text',
        );

        final editedMessage = await repository.editMessage(
          messageId: message.id,
          newText: 'Edited text',
        );

        expect(editedMessage.text, equals('Edited text'));
        expect(editedMessage.isEdited, isTrue);
        expect(editedMessage.editedAt, isNotNull);

        // Verify it's updated in storage
        final messages = await repository.getMessages(baseId: 'base_1');
        final updatedMessage = messages.firstWhere((m) => m.id == message.id);
        expect(updatedMessage.text, equals('Edited text'));
        expect(updatedMessage.isEdited, isTrue);
      });

      test('should throw exception for non-existent message', () async {
        expect(
          () => repository.editMessage(
            messageId: 'non-existent',
            newText: 'New text',
          ),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('deleteMessage', () {
      test('should soft delete message', () async {
        final message = await repository.sendMessage(
          baseId: 'base_1',
          authorUserId: 'user_123',
          type: MessageType.text,
          text: 'To be deleted',
        );

        await repository.deleteMessage(message.id);

        // Verify it's soft deleted
        final messages = await repository.getMessages(baseId: 'base_1');
        final deletedMessage = messages.firstWhere((m) => m.id == message.id);
        expect(deletedMessage.isDeleted, isTrue);
        expect(deletedMessage.text, isNull);
      });

      test('should throw exception for non-existent message', () async {
        expect(
          () => repository.deleteMessage('non-existent'),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('getMessage', () {
      test('should get message by id', () async {
        final message = await repository.sendMessage(
          baseId: 'base_1',
          authorUserId: 'user_123',
          type: MessageType.text,
          text: 'Test message',
        );

        final retrievedMessage = await repository.getMessage(message.id);
        expect(retrievedMessage, isNotNull);
        expect(retrievedMessage!.id, equals(message.id));
        expect(retrievedMessage.text, equals('Test message'));
      });

      test('should return null for non-existent message', () async {
        final message = await repository.getMessage('non-existent');
        expect(message, isNull);
      });
    });
  });
}
