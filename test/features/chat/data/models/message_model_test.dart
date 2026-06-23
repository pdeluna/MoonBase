import 'package:flutter_test/flutter_test.dart';

import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/core/sync_status.dart';
import 'package:moonbase_skeleton/features/chat/data/models/message_model.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_type.dart';

MediaRef _image({String id = 'm0', String key = 'b1/m0.jpg'}) => MediaRef(
      id: MediaId(id),
      type: MediaType.image,
      storageKey: key,
      width: 800,
      height: 600,
      sizeBytes: 12345,
      mimeType: 'image/jpeg',
    );

MediaRef _video({String id = 'm1', String key = 'b1/m1.mp4'}) => MediaRef(
      id: MediaId(id),
      type: MediaType.video,
      storageKey: key,
      thumbnailKey: 'b1/m1.thumb.jpg',
      duration: const Duration(seconds: 12),
      sizeBytes: 5000000,
      mimeType: 'video/mp4',
    );

void main() {
  group('MessageModel', () {
    test('round-trips a text-only message (legacy Phase 2 shape stays intact)',
        () {
      final model = MessageModel(
        id: 'm1',
        baseId: 'b1',
        userId: 'u1',
        content: 'hello',
        createdAt: DateTime.utc(2026, 6, 22, 12, 0),
      );

      final restored = MessageModel.fromMap(model.toMap());

      expect(restored.id, 'm1');
      expect(restored.baseId, 'b1');
      expect(restored.userId, 'u1');
      expect(restored.content, 'hello');
      expect(restored.createdAt.toUtc(), DateTime.utc(2026, 6, 22, 12, 0));
      expect(restored.media, isEmpty);
      expect(restored.syncStatus, SyncStatus.synced);
    });

    test('round-trips a message with mixed image + video media', () {
      final media = [_image(), _video()];
      final model = MessageModel(
        id: 'm2',
        baseId: 'b1',
        userId: 'u1',
        content: 'look at this',
        createdAt: DateTime.utc(2026, 6, 22, 12, 0),
        media: media,
        syncStatus: SyncStatus.localOnly,
      );

      final restored = MessageModel.fromMap(model.toMap());

      expect(restored.media.length, 2);
      expect(restored.media[0].type, MediaType.image);
      expect(restored.media[0].storageKey, 'b1/m0.jpg');
      expect(restored.media[0].width, 800);
      expect(restored.media[0].height, 600);
      expect(restored.media[0].mimeType, 'image/jpeg');
      expect(restored.media[1].type, MediaType.video);
      expect(restored.media[1].thumbnailKey, 'b1/m1.thumb.jpg');
      expect(restored.media[1].duration, const Duration(seconds: 12));
      expect(restored.syncStatus, SyncStatus.localOnly);
    });

    test('reads a Phase 2 row missing media/syncStatus with safe defaults', () {
      // Simulate an on-disk row written by the Phase 2 schema.
      final legacy = <String, dynamic>{
        'id': 'm_legacy',
        'baseId': 'b1',
        'userId': 'u1',
        'content': 'old',
        'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
      };

      final restored = MessageModel.fromMap(legacy);

      expect(restored.media, isEmpty);
      expect(restored.syncStatus, SyncStatus.synced);
    });

    test('coerces an unknown syncStatus name back to synced', () {
      final corrupt = <String, dynamic>{
        'id': 'm1',
        'baseId': 'b1',
        'userId': 'u1',
        'content': 'x',
        'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
        'syncStatus': 'not_a_real_state',
      };

      final restored = MessageModel.fromMap(corrupt);

      expect(restored.syncStatus, SyncStatus.synced);
    });

    test('toEntity carries media + syncStatus through to the Message entity',
        () {
      final media = [_image()];
      final model = MessageModel(
        id: 'm1',
        baseId: 'b1',
        userId: 'u1',
        content: 'hi',
        createdAt: DateTime.utc(2026, 6, 22, 12, 0),
        media: media,
        syncStatus: SyncStatus.localOnly,
      );

      final entity = model.toEntity();

      expect(entity.id, const MessageId('m1'));
      expect(entity.baseId, const BaseId('b1'));
      expect(entity.userId, const UserId('u1'));
      expect(entity.media, equals(media));
      expect(entity.syncStatus, SyncStatus.localOnly);
    });
  });
}
