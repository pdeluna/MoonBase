import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/core/sync_status.dart';
import 'package:moonbase_skeleton/features/chat/data/models/message_model.dart';
import 'package:moonbase_skeleton/features/media/data/firebase_storage_path.dart';
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

    test('toFirestore always includes mediaPaths [] for text-only / local keys',
        () {
      final model = MessageModel(
        id: 'm1',
        baseId: 'b1',
        userId: 'uid_alice',
        content: 'hello',
        createdAt: DateTime.utc(2026, 8, 4, 12, 0),
        // Local Phase 3 keys must not be written as mediaPaths.
        media: [_image()],
      );

      final payload = model.toFirestore();

      expect(payload.keys.toSet(), {
        'authorUid',
        'text',
        'createdAt',
        'schemaVersion',
        'mediaPaths',
      });
      expect(payload['authorUid'], 'uid_alice');
      expect(payload['text'], 'hello');
      expect(payload['schemaVersion'], MessageModel.firestoreSchemaVersion);
      expect(payload['createdAt'], isA<FieldValue>());
      expect(payload['mediaPaths'], isEmpty);
    });

    test('toFirestore emits cloud storagePathFor keys in mediaPaths', () {
      const uuid = '550e8400-e29b-41d4-a716-446655440000';
      final cloudPath = storagePathFor(baseId: 'b1'.bid, uuid: uuid);
      final model = MessageModel(
        id: 'm1',
        baseId: 'b1',
        userId: 'uid_alice',
        content: 'look',
        createdAt: DateTime.utc(2026, 8, 4, 12, 0),
        media: [
          MediaRef(
            id: const MediaId(uuid),
            type: MediaType.image,
            storageKey: cloudPath,
            width: 800,
            height: 600,
            mimeType: 'image/jpeg',
          ),
        ],
      );

      final payload = model.toFirestore();
      expect(payload['mediaPaths'], [cloudPath]);
    });

    test('fromFirestore maps authorUid/text and Timestamp createdAt', () {
      final restored = MessageModel.fromFirestore('mid1', 'base1', {
        'authorUid': 'uid_bob',
        'text': 'hi base',
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 8, 4, 15, 0)),
        'schemaVersion': 1,
        'mediaPaths': <String>[],
      });

      expect(restored.id, 'mid1');
      expect(restored.baseId, 'base1');
      expect(restored.userId, 'uid_bob');
      expect(restored.content, 'hi base');
      expect(restored.createdAt, DateTime.utc(2026, 8, 4, 15, 0));
      expect(restored.media, isEmpty);
      expect(restored.syncStatus, SyncStatus.synced);
    });

    test('fromFirestore rebuilds lossy MediaRefs from mediaPaths', () {
      const uuid = '550e8400-e29b-41d4-a716-446655440000';
      final path = storagePathFor(baseId: 'base1'.bid, uuid: uuid);
      final restored = MessageModel.fromFirestore('mid1', 'base1', {
        'authorUid': 'uid_bob',
        'text': 'pic',
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 8, 4, 15, 0)),
        'schemaVersion': 1,
        'mediaPaths': [path],
      });

      expect(restored.media.length, 1);
      expect(restored.media.single.id, const MediaId(uuid));
      expect(restored.media.single.type, MediaType.image);
      expect(restored.media.single.storageKey, path);
      expect(restored.media.single.width, isNull);
      expect(restored.media.single.height, isNull);
      expect(restored.media.single.mimeType, isNull);
      expect(restored.media.single.sizeBytes, isNull);
      expect(restored.media.single.thumbnailKey, isNull);
      expect(restored.media.single.duration, isNull);
      expect(restored.media.single.syncStatus, SyncStatus.synced);
    });

    test('fromFirestore uses newest-end now() when createdAt is null (pending)',
        () {
      final before = DateTime.now().toUtc();
      final restored = MessageModel.fromFirestore('mid2', 'base1', {
        'authorUid': 'uid_bob',
        'text': 'pending',
        'createdAt': null,
        'schemaVersion': 1,
        'mediaPaths': <String>[],
      });
      final after = DateTime.now().toUtc();

      expect(restored.createdAt.isBefore(before.subtract(const Duration(seconds: 1))),
          isFalse);
      expect(
        !restored.createdAt.isAfter(after.add(const Duration(seconds: 1))),
        isTrue,
      );
    });
  });
}
