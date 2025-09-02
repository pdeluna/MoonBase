import 'package:flutter_test/flutter_test.dart';
import 'package:moonbase_skeleton/providers/chat_provider.dart';
import 'package:moonbase_skeleton/models/chat_message.dart';
import 'package:moonbase_skeleton/models/enums.dart';
import 'package:moonbase_skeleton/models/base.dart';
import 'package:moonbase_skeleton/models/profile.dart';

void main() {
  group('ChatProvider Tests', () {
    late Base testBase;
    late List<ChatMessage> testMessages;

    setUp(() {
      testBase = Base(
        id: 'test_base_123',
        name: 'Test Base',
        ownerUserId: 'user_123',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
        lastAccessedAt: DateTime(2024, 1, 15),
      );
      
      testMessages = [
        ChatMessage(
          id: 'msg_1',
          baseId: testBase.id,
          authorUserId: 'user_123',
          type: MessageType.text,
          text: 'Hello World',
          createdAt: DateTime(2024, 1, 15, 10, 0),
        ),
        ChatMessage(
          id: 'msg_2',
          baseId: testBase.id,
          authorUserId: 'user_456',
          type: MessageType.text,
          text: 'Hi there!',
          createdAt: DateTime(2024, 1, 15, 10, 1),
        ),
      ];
    });

    group('ChatPaginationState', () {
      test('should create with default values', () {
        const state = ChatPaginationState();
        
        expect(state.isLoadingMore, isFalse);
        expect(state.hasMoreMessages, isTrue);
        expect(state.lastMessageId, isNull);
        expect(state.error, isNull);
      });

      test('should copy with new values', () {
        const initialState = ChatPaginationState();
        final newState = initialState.copyWith(
          isLoadingMore: true,
          hasMoreMessages: false,
          lastMessageId: 'msg_123',
          error: 'Test error',
        );
        
        expect(newState.isLoadingMore, isTrue);
        expect(newState.hasMoreMessages, isFalse);
        expect(newState.lastMessageId, equals('msg_123'));
        expect(newState.error, equals('Test error'));
      });

      test('should copy with partial values', () {
        const initialState = ChatPaginationState(
          isLoadingMore: true,
          hasMoreMessages: false,
          lastMessageId: 'msg_123',
          error: 'Test error',
        );
        
        final newState = initialState.copyWith(isLoadingMore: false);
        
        expect(newState.isLoadingMore, isFalse);
        expect(newState.hasMoreMessages, isFalse); // Should remain unchanged
        expect(newState.lastMessageId, equals('msg_123')); // Should remain unchanged
        expect(newState.error, equals('Test error')); // Should remain unchanged
      });
    });

    group('ChatPaginationNotifier', () {
      test('should manage pagination state correctly', () {
        final notifier = ChatPaginationNotifier();
        
        expect(notifier.state.isLoadingMore, isFalse);
        expect(notifier.state.hasMoreMessages, isTrue);
        expect(notifier.state.lastMessageId, isNull);
        expect(notifier.state.error, isNull);
        
        notifier.setLoadingMore(true);
        expect(notifier.state.isLoadingMore, isTrue);
        
        notifier.setHasMoreMessages(false);
        expect(notifier.state.hasMoreMessages, isFalse);
        
        notifier.setLastMessageId('msg_123');
        expect(notifier.state.lastMessageId, equals('msg_123'));
        
        notifier.setError('Test error');
        expect(notifier.state.error, equals('Test error'));
      });

      test('should reset state correctly', () {
        final notifier = ChatPaginationNotifier();
        
        notifier.setLoadingMore(true);
        notifier.setHasMoreMessages(false);
        notifier.setLastMessageId('msg_123');
        notifier.setError('Test error');
        
        notifier.reset();
        
        expect(notifier.state.isLoadingMore, isFalse);
        expect(notifier.state.hasMoreMessages, isTrue);
        expect(notifier.state.lastMessageId, isNull);
        expect(notifier.state.error, isNull);
      });
    });

    group('ChatMessage Operations', () {
      test('should create chat message with correct properties', () {
        final message = ChatMessage(
          id: 'test_msg',
          baseId: testBase.id,
          authorUserId: 'user_123',
          type: MessageType.text,
          text: 'Test message',
          createdAt: DateTime(2024, 1, 15, 10, 0),
        );
        
        expect(message.id, equals('test_msg'));
        expect(message.baseId, equals(testBase.id));
        expect(message.authorUserId, equals('user_123'));
        expect(message.type, equals(MessageType.text));
        expect(message.text, equals('Test message'));
        expect(message.isEdited, isFalse);
        expect(message.isDeleted, isFalse);
      });

      test('should copy chat message with new values', () {
        final originalMessage = testMessages.first;
        final editedMessage = originalMessage.copyWith(
          text: 'Edited message',
          isEdited: true,
          editedAt: DateTime.now(),
        );
        
        expect(editedMessage.id, equals(originalMessage.id));
        expect(editedMessage.text, equals('Edited message'));
        expect(editedMessage.isEdited, isTrue);
        expect(editedMessage.editedAt, isNotNull);
        expect(editedMessage.isDeleted, isFalse); // Should remain unchanged
      });

      test('should mark message as deleted', () {
        final originalMessage = testMessages.first;
        final deletedMessage = originalMessage.copyWith(
          text: null,
          isDeleted: true,
        );
        
        expect(deletedMessage.text, isNull);
        expect(deletedMessage.isDeleted, isTrue);
        expect(deletedMessage.id, equals(originalMessage.id)); // Should remain unchanged
      });
    });

    group('Message Type Handling', () {
      test('should handle different message types', () {
        final textMessage = ChatMessage(
          id: 'text_msg',
          baseId: testBase.id,
          authorUserId: 'user_123',
          type: MessageType.text,
          text: 'Text message',
          createdAt: DateTime.now(),
        );
        
        final mediaMessage = ChatMessage(
          id: 'media_msg',
          baseId: testBase.id,
          authorUserId: 'user_123',
          type: MessageType.media,
          text: null,
          createdAt: DateTime.now(),
        );
        
        expect(textMessage.type, equals(MessageType.text));
        expect(mediaMessage.type, equals(MessageType.media));
        expect(textMessage.text, isNotNull);
        expect(mediaMessage.text, isNull);
      });
    });

    group('Message Threading', () {
      test('should handle reply to message', () {
        final originalMessage = testMessages.first;
        final replyMessage = ChatMessage(
          id: 'reply_msg',
          baseId: testBase.id,
          authorUserId: 'user_456',
          type: MessageType.text,
          text: 'This is a reply',
          createdAt: DateTime.now(),
          replyToMessageId: originalMessage.id,
        );
        
        expect(replyMessage.replyToMessageId, equals(originalMessage.id));
        expect(replyMessage.baseId, equals(originalMessage.baseId));
      });
    });

    group('Message Validation', () {
      test('should validate message structure', () {
        final message = ChatMessage(
          id: 'valid_msg',
          baseId: testBase.id,
          authorUserId: 'user_123',
          type: MessageType.text,
          text: 'Valid message',
          createdAt: DateTime.now(),
        );
        
        expect(message.id, isNotEmpty);
        expect(message.baseId, isNotEmpty);
        expect(message.authorUserId, isNotEmpty);
        expect(message.createdAt, isA<DateTime>());
      });

      test('should handle empty text for non-text messages', () {
        final mediaMessage = ChatMessage(
          id: 'media_msg',
          baseId: testBase.id,
          authorUserId: 'user_123',
          type: MessageType.media,
          text: null, // Valid for media messages
          createdAt: DateTime.now(),
        );
        
        expect(mediaMessage.text, isNull);
        expect(mediaMessage.type, equals(MessageType.media));
      });
    });
  });
}
