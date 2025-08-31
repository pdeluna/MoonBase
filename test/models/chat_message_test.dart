import 'package:flutter_test/flutter_test.dart';
import 'package:moonbase_skeleton/models/models.dart';

void main() {
  group('ChatMessage Model Tests', () {
    test('should create ChatMessage with required fields', () {
      final message = ChatMessage(
        id: 'test-id',
        baseId: 'base-id',
        authorUserId: 'author-id',
        type: MessageType.text,
        createdAt: DateTime(2024, 1, 1),
      );

      expect(message.id, 'test-id');
      expect(message.baseId, 'base-id');
      expect(message.authorUserId, 'author-id');
      expect(message.type, MessageType.text);
      expect(message.text, isNull);
      expect(message.media, isNull);
      expect(message.isEdited, false);
      expect(message.isDeleted, false);
      expect(message.replyToMessageId, isNull);
      expect(message.editedAt, isNull);
    });

    test('should create ChatMessage with all fields', () {
      final message = ChatMessage(
        id: 'test-id',
        baseId: 'base-id',
        authorUserId: 'author-id',
        type: MessageType.media,
        text: 'Hello world!',
        media: const [
          MediaRef(
            id: 'media-id',
            type: MediaType.image,
            uri: 'https://example.com/image.jpg',
            width: 800,
            height: 600,
          ),
        ],
        createdAt: DateTime(2024, 1, 1),
        editedAt: DateTime(2024, 1, 1, 12, 0, 0),
        replyToMessageId: 'reply-id',
        isEdited: true,
        isDeleted: false,
      );

      expect(message.text, 'Hello world!');
      expect(message.media, hasLength(1));
      expect(message.media!.first.id, 'media-id');
      expect(message.isEdited, true);
      expect(message.replyToMessageId, 'reply-id');
      expect(message.editedAt, DateTime(2024, 1, 1, 12, 0, 0));
    });

    test('should serialize and deserialize correctly', () {
      final original = ChatMessage(
        id: 'test-id',
        baseId: 'base-id',
        authorUserId: 'author-id',
        type: MessageType.media,
        text: 'Hello world!',
        media: const [
          MediaRef(
            id: 'media-id',
            type: MediaType.image,
            uri: 'https://example.com/image.jpg',
            width: 800,
            height: 600,
          ),
        ],
        createdAt: DateTime(2024, 1, 1, 12, 0, 0),
        editedAt: DateTime(2024, 1, 1, 12, 0, 0),
        replyToMessageId: 'reply-id',
        isEdited: true,
        isDeleted: false,
      );

      final json = original.toMap();
      final restored = ChatMessage.fromMap(json);

      expect(restored.id, original.id);
      expect(restored.baseId, original.baseId);
      expect(restored.authorUserId, original.authorUserId);
      expect(restored.type, original.type);
      expect(restored.text, original.text);
      expect(restored.media, hasLength(original.media!.length));
      expect(restored.media!.first.id, original.media!.first.id);
      expect(restored.isEdited, original.isEdited);
      expect(restored.isDeleted, original.isDeleted);
      expect(restored.replyToMessageId, original.replyToMessageId);
      expect(restored.editedAt, original.editedAt);
      expect(restored.createdAt, original.createdAt);
    });

    test('should handle JSON serialization', () {
      final message = ChatMessage(
        id: 'test-id',
        baseId: 'base-id',
        authorUserId: 'author-id',
        type: MessageType.text,
        text: 'Hello world!',
        createdAt: DateTime(2024, 1, 1),
      );

      final jsonString = message.toJson();
      final restored = ChatMessage.fromJson(jsonString);

      expect(restored.id, message.id);
      expect(restored.baseId, message.baseId);
      expect(restored.authorUserId, message.authorUserId);
      expect(restored.type, message.type);
      expect(restored.text, message.text);
    });

    test('should handle copyWith correctly', () {
      final original = ChatMessage(
        id: 'test-id',
        baseId: 'base-id',
        authorUserId: 'author-id',
        type: MessageType.text,
        text: 'Original text',
        createdAt: DateTime(2024, 1, 1),
      );

      final updated = original.copyWith(
        text: 'Updated text',
        isEdited: true,
        editedAt: DateTime(2024, 1, 1, 12, 0, 0),
        replyToMessageId: 'reply-id',
      );

      expect(updated.id, original.id);
      expect(updated.baseId, original.baseId);
      expect(updated.authorUserId, original.authorUserId);
      expect(updated.type, original.type);
      expect(updated.text, 'Updated text');
      expect(updated.isEdited, true);
      expect(updated.editedAt, DateTime(2024, 1, 1, 12, 0, 0));
      expect(updated.replyToMessageId, 'reply-id');
      expect(updated.createdAt, original.createdAt);
    });

    test('should handle equality correctly', () {
      final message1 = ChatMessage(
        id: 'test-id',
        baseId: 'base-id',
        authorUserId: 'author-id',
        type: MessageType.text,
        createdAt: DateTime(2024, 1, 1),
      );

      final message2 = ChatMessage(
        id: 'test-id',
        baseId: 'different-base',
        authorUserId: 'different-author',
        type: MessageType.media,
        createdAt: DateTime(2024, 1, 2),
      );

      final message3 = ChatMessage(
        id: 'different-id',
        baseId: 'base-id',
        authorUserId: 'author-id',
        type: MessageType.text,
        createdAt: DateTime(2024, 1, 1),
      );

      expect(message1, equals(message2)); // Same ID
      expect(message1, isNot(equals(message3))); // Different ID
    });

    test('should handle hashCode correctly', () {
      final message1 = ChatMessage(
        id: 'test-id',
        baseId: 'base-id',
        authorUserId: 'author-id',
        type: MessageType.text,
        createdAt: DateTime(2024, 1, 1),
      );

      final message2 = ChatMessage(
        id: 'test-id',
        baseId: 'different-base',
        authorUserId: 'different-author',
        type: MessageType.media,
        createdAt: DateTime(2024, 1, 2),
      );

      expect(message1.hashCode, equals(message2.hashCode));
    });

    test('should handle different message types', () {
      final textMessage = ChatMessage(
        id: 'text-id',
        baseId: 'base-id',
        authorUserId: 'author-id',
        type: MessageType.text,
        text: 'Text message',
        createdAt: DateTime(2024, 1, 1),
      );

      final mediaMessage = ChatMessage(
        id: 'media-id',
        baseId: 'base-id',
        authorUserId: 'author-id',
        type: MessageType.media,
        media: const [
          MediaRef(
            id: 'media-ref-id',
            type: MediaType.image,
            uri: 'https://example.com/image.jpg',
          ),
        ],
        createdAt: DateTime(2024, 1, 1),
      );

      final systemMessage = ChatMessage(
        id: 'system-id',
        baseId: 'base-id',
        authorUserId: 'system',
        type: MessageType.system,
        text: 'System message',
        createdAt: DateTime(2024, 1, 1),
      );

      expect(textMessage.type, MessageType.text);
      expect(mediaMessage.type, MessageType.media);
      expect(systemMessage.type, MessageType.system);
      expect(textMessage.text, 'Text message');
      expect(mediaMessage.media, hasLength(1));
      expect(systemMessage.text, 'System message');
    });

    test('should handle null media in fromMap', () {
      final map = {
        'id': 'test-id',
        'baseId': 'base-id',
        'authorUserId': 'author-id',
        'type': 'text',
        'text': 'Hello world!',
        'media': null,
        'createdAt': '2024-01-01T00:00:00.000Z',
        'editedAt': null,
        'replyToMessageId': null,
        'isEdited': false,
        'isDeleted': false,
      };

      final message = ChatMessage.fromMap(map);
      expect(message.media, isNull);
      expect(message.text, 'Hello world!');
    });
  });
}
