import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/media/data/datasources/firebase_media_storage.dart';
import 'package:moonbase_skeleton/features/media/data/firebase_storage_path.dart';

/// Minimal JPEG (SOI + EOI) — enough for tests that stub compression.
Uint8List _tinyJpeg() => Uint8List.fromList([0xff, 0xd8, 0xff, 0xd9]);

void main() {
  const uuid = '550e8400-e29b-41d4-a716-446655440000';
  const localKey = 'base1/$uuid.png';
  final cloudPath = storagePathFor(baseId: 'base1'.bid, uuid: uuid);

  group('FirebaseMediaStorage.putBytes', () {
    test('compresses, uploads with image/jpeg metadata, returns cloud path',
        () async {
      String? uploadedPath;
      String? uploadedContentType;
      Uint8List? uploadedBytes;

      final storage = FirebaseMediaStorage(
        compressJpeg: (bytes, {required quality, required maxEdge}) async {
          expect(quality, 80);
          expect(maxEdge, 1920);
          return _tinyJpeg();
        },
        putObject: ({
          required path,
          required bytes,
          required contentType,
        }) async {
          uploadedPath = path;
          uploadedBytes = bytes;
          uploadedContentType = contentType;
        },
      );

      final returned = await storage.putBytes(
        key: localKey,
        bytes: Uint8List.fromList(List.filled(100, 1)),
        mimeType: 'image/png',
      );

      expect(returned, cloudPath);
      expect(uploadedPath, cloudPath);
      expect(uploadedContentType, 'image/jpeg');
      expect(uploadedBytes, _tinyJpeg());
    });

    test('accepts canonical cloud key without rewrite', () async {
      String? uploadedPath;
      final storage = FirebaseMediaStorage(
        compressJpeg: (bytes, {required quality, required maxEdge}) async =>
            _tinyJpeg(),
        putObject: ({
          required path,
          required bytes,
          required contentType,
        }) async {
          uploadedPath = path;
        },
      );

      final returned = await storage.putBytes(
        key: cloudPath,
        bytes: _tinyJpeg(),
        mimeType: 'image/jpeg',
      );

      expect(returned, cloudPath);
      expect(uploadedPath, cloudPath);
    });

    test('throws ValidationFailure on unparseable key (loud, no upload)',
        () async {
      var putCalled = false;
      final storage = FirebaseMediaStorage(
        compressJpeg: (bytes, {required quality, required maxEdge}) async =>
            _tinyJpeg(),
        putObject: ({
          required path,
          required bytes,
          required contentType,
        }) async {
          putCalled = true;
        },
      );

      expect(
        () => storage.putBytes(
          key: 'base1/not-a-uuid.jpg',
          bytes: _tinyJpeg(),
          mimeType: 'image/jpeg',
        ),
        throwsA(isA<ValidationFailure>()),
      );
      expect(putCalled, isFalse);
    });

    test('throws MediaUnsupportedFailure when compress returns null', () async {
      final storage = FirebaseMediaStorage(
        compressJpeg: (bytes, {required quality, required maxEdge}) async =>
            null,
        putObject: ({
          required path,
          required bytes,
          required contentType,
        }) async {},
      );

      expect(
        () => storage.putBytes(
          key: localKey,
          bytes: _tinyJpeg(),
          mimeType: 'image/heic',
        ),
        throwsA(isA<MediaUnsupportedFailure>()),
      );
    });

    test('throws MediaTooLargeFailure when every quality stays over cap',
        () async {
      final oversized = Uint8List(100);
      final storage = FirebaseMediaStorage(
        maxBytes: 10,
        compressJpeg: (bytes, {required quality, required maxEdge}) async =>
            oversized,
        putObject: ({
          required path,
          required bytes,
          required contentType,
        }) async {},
      );

      expect(
        () => storage.putBytes(
          key: localKey,
          bytes: _tinyJpeg(),
          mimeType: 'image/jpeg',
        ),
        throwsA(isA<MediaTooLargeFailure>()),
      );
    });

    test('quality ladder stops when a step fits under the cap', () async {
      final qualities = <int>[];
      final storage = FirebaseMediaStorage(
        maxBytes: 50,
        initialQuality: 80,
        compressJpeg: (bytes, {required quality, required maxEdge}) async {
          qualities.add(quality);
          if (quality > 55) {
            return Uint8List(100);
          }
          return Uint8List(20);
        },
        putObject: ({
          required path,
          required bytes,
          required contentType,
        }) async {},
      );

      await storage.putBytes(
        key: localKey,
        bytes: _tinyJpeg(),
        mimeType: 'image/jpeg',
      );

      expect(qualities, containsAll([80, 70, 55]));
      expect(qualities.last, 55);
    });
  });

  group('FirebaseMediaStorage.resolveUri', () {
    test('returns download URL for canonical cloud path', () async {
      String? requestedPath;
      final storage = FirebaseMediaStorage(
        compressJpeg: (bytes, {required quality, required maxEdge}) async =>
            _tinyJpeg(),
        putObject: ({
          required path,
          required bytes,
          required contentType,
        }) async {},
        getDownloadUrl: (path) async {
          requestedPath = path;
          return 'https://firebasestorage.googleapis.com/v0/b/x/o/'
              '${Uri.encodeComponent(path)}?token=rotating';
        },
      );

      final uri = await storage.resolveUri(cloudPath);

      expect(requestedPath, cloudPath);
      expect(uri, contains('token=rotating'));
      expect(uri, startsWith('https://'));
    });

    test('maps local staging key to cloud path before getDownloadURL', () async {
      String? requestedPath;
      final storage = FirebaseMediaStorage(
        compressJpeg: (bytes, {required quality, required maxEdge}) async =>
            _tinyJpeg(),
        putObject: ({
          required path,
          required bytes,
          required contentType,
        }) async {},
        getDownloadUrl: (path) async {
          requestedPath = path;
          return 'https://example.com/$path';
        },
      );

      await storage.resolveUri(localKey);

      expect(requestedPath, cloudPath);
    });

    test('throws ValidationFailure on unparseable key (no network)', () async {
      var getCalled = false;
      final storage = FirebaseMediaStorage(
        compressJpeg: (bytes, {required quality, required maxEdge}) async =>
            _tinyJpeg(),
        putObject: ({
          required path,
          required bytes,
          required contentType,
        }) async {},
        getDownloadUrl: (path) async {
          getCalled = true;
          return 'https://example.com';
        },
      );

      expect(
        () => storage.resolveUri('base1/not-a-uuid.jpg'),
        throwsA(isA<ValidationFailure>()),
      );
      expect(getCalled, isFalse);
    });

    test('memoizes getDownloadURL per path across resolveUri calls', () async {
      var getCalls = 0;
      final storage = FirebaseMediaStorage(
        compressJpeg: (bytes, {required quality, required maxEdge}) async =>
            _tinyJpeg(),
        putObject: ({
          required path,
          required bytes,
          required contentType,
        }) async {},
        getDownloadUrl: (path) async {
          getCalls++;
          return 'https://example.com/$path';
        },
      );

      final a = storage.resolveUri(cloudPath);
      final b = storage.resolveUri(cloudPath);
      expect(identical(a, b), isTrue);
      expect(await a, 'https://example.com/$cloudPath');
      expect(await b, 'https://example.com/$cloudPath');
      expect(getCalls, 1);
    });

    test('timeout throws NetworkFailure and allows retry', () async {
      var getCalls = 0;
      final storage = FirebaseMediaStorage(
        resolveTimeout: const Duration(milliseconds: 20),
        compressJpeg: (bytes, {required quality, required maxEdge}) async =>
            _tinyJpeg(),
        putObject: ({
          required path,
          required bytes,
          required contentType,
        }) async {},
        getDownloadUrl: (path) async {
          getCalls++;
          if (getCalls == 1) {
            await Future<void>.delayed(const Duration(milliseconds: 100));
            return 'https://example.com/late';
          }
          return 'https://example.com/ok';
        },
      );

      await expectLater(
        storage.resolveUri(cloudPath),
        throwsA(isA<NetworkFailure>()),
      );
      expect(await storage.resolveUri(cloudPath), 'https://example.com/ok');
      expect(getCalls, 2);
    });
  });

  group('FirebaseMediaStorage stubs', () {
    test('delete is UnimplementedError permanently (Storage delete ADR)', () {
      final storage = FirebaseMediaStorage(
        compressJpeg: (bytes, {required quality, required maxEdge}) async =>
            _tinyJpeg(),
        putObject: ({
          required path,
          required bytes,
          required contentType,
        }) async {},
      );
      expect(
        () => storage.delete(cloudPath),
        throwsA(isA<UnimplementedError>()),
      );
    });
  });
}
