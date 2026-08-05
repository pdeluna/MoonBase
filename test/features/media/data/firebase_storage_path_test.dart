import 'package:flutter_test/flutter_test.dart';

import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/media/data/firebase_storage_path.dart';

void main() {
  group('storagePathFor', () {
    test('builds locked bases/{baseId}/media/{uuid}.jpg shape', () {
      const uuid = '550e8400-e29b-41d4-a716-446655440000';
      expect(
        storagePathFor(baseId: 'base1'.bid, uuid: uuid),
        'bases/base1/media/$uuid.jpg',
      );
    });

    test('isFirebaseStoragePathForBase accepts only this-base uuid.jpg paths',
        () {
      const uuid = '550e8400-e29b-41d4-a716-446655440000';
      final path = storagePathFor(baseId: 'base1'.bid, uuid: uuid);
      expect(isFirebaseStoragePathForBase(path, 'base1'.bid), isTrue);
      expect(isFirebaseStoragePathForBase(path, 'other'.bid), isFalse);
      expect(isFirebaseStoragePathForBase('base1/$uuid.jpg', 'base1'.bid), isFalse);
      expect(
        isFirebaseStoragePathForBase('bases/base1/media/not-a-uuid.jpg', 'base1'.bid),
        isFalse,
      );
      expect(
        isFirebaseStoragePathForBase('bases/base1/media/$uuid.png', 'base1'.bid),
        isFalse,
      );
    });

    test('mediaUuidFromStoragePath reads leaf uuid', () {
      const uuid = '550e8400-e29b-41d4-a716-446655440000';
      final path = storagePathFor(baseId: 'base1'.bid, uuid: uuid);
      expect(mediaUuidFromStoragePath(path), uuid);
      expect(mediaUuidFromStoragePath('bases/base1/media/not-a-uuid.jpg'), isNull);
    });
  });
}
