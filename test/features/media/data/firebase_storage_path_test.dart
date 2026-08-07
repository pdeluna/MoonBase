import 'package:flutter_test/flutter_test.dart';

import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/media/data/firebase_storage_path.dart';

void main() {
  const uuid = '550e8400-e29b-41d4-a716-446655440000';

  group('storagePathFor', () {
    test('builds locked bases/{baseId}/media/{uuid}.jpg shape', () {
      expect(
        storagePathFor(baseId: 'base1'.bid, uuid: uuid),
        'bases/base1/media/$uuid.jpg',
      );
    });

    test('isFirebaseStoragePathForBase accepts only this-base uuid.jpg paths',
        () {
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
      final path = storagePathFor(baseId: 'base1'.bid, uuid: uuid);
      expect(mediaUuidFromStoragePath(path), uuid);
      expect(mediaUuidFromStoragePath('bases/base1/media/not-a-uuid.jpg'), isNull);
    });
  });

  group('cloudStoragePathFromKey', () {
    test('rewrites local <baseId>/<uuid>.<ext> to storagePathFor', () {
      expect(
        cloudStoragePathFromKey('base1/$uuid.jpg'),
        'bases/base1/media/$uuid.jpg',
      );
      expect(
        cloudStoragePathFromKey('base1/$uuid.png'),
        'bases/base1/media/$uuid.jpg',
      );
      expect(
        cloudStoragePathFromKey('base1/$uuid.heic'),
        'bases/base1/media/$uuid.jpg',
      );
    });

    test('accepts already-canonical cloud path', () {
      final cloud = 'bases/base1/media/$uuid.jpg';
      expect(cloudStoragePathFromKey(cloud), cloud);
    });

    test('rejects empty, absolute, traversal, nested, poster, bad leaf', () {
      final bad = <String>[
        '',
        '/base1/$uuid.jpg',
        'base1/../$uuid.jpg',
        'base1/sub/$uuid.jpg',
        'base1/$uuid.thumb.jpg',
        'base1/not-a-uuid.jpg',
        'bases/base1/media/',
        'bases/base1/media/$uuid.png',
        'bases/other/media/$uuid.jpg'.replaceFirst('other', 'x/y'),
        'x/bases/base1/media/$uuid.jpg',
      ];
      for (final key in bad) {
        expect(
          () => cloudStoragePathFromKey(key),
          throwsA(isA<ValidationFailure>()),
          reason: 'expected ValidationFailure for "$key"',
        );
      }
    });
  });
}
