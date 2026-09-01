import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/media/data/datasources/local_file_media_storage.dart';
import 'package:moonbase_skeleton/features/media/data/datasources/resolving_media_storage.dart';
import 'package:moonbase_skeleton/features/media/data/firebase_storage_path.dart';
import 'package:moonbase_skeleton/features/media/domain/repositories/media_storage.dart';

class _FakeCloudStorage implements MediaStorage {
  _FakeCloudStorage({this.downloadUrl = 'https://example.com/tokenized.jpg'});

  final String downloadUrl;
  final List<String> resolveCalls = <String>[];
  Object? resolveError;

  @override
  Future<String> putBytes({
    required String key,
    required List<int> bytes,
    required String mimeType,
  }) async =>
      key;

  @override
  Future<String> resolveUri(String key) async {
    resolveCalls.add(key);
    final err = resolveError;
    if (err != null) throw err;
    return downloadUrl;
  }

  @override
  Future<void> delete(String key) async {}
}

void main() {
  const uuid = '550e8400-e29b-41d4-a716-446655440000';
  final cloudPath = storagePathFor(baseId: 'base1'.bid, uuid: uuid);

  late Directory tempDir;
  late LocalFileMediaStorage local;
  late _FakeCloudStorage cloud;
  late ResolvingMediaStorage storage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mb_resolving_');
    local = LocalFileMediaStorage(tempDir);
    cloud = _FakeCloudStorage();
    storage = ResolvingMediaStorage(local: local, cloud: cloud);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('ResolvingMediaStorage.resolveUri', () {
    test('local keys stay on LocalFileMediaStorage (no cloud call)', () async {
      const localKey = 'base1/$uuid.jpg';
      await local.putBytes(
        key: localKey,
        bytes: <int>[1, 2, 3],
        mimeType: 'image/jpeg',
      );

      final uri = await storage.resolveUri(localKey);

      expect(uri, startsWith('file://'));
      expect(cloud.resolveCalls, isEmpty);
    });

    test('cloud key prefers renderable local sibling (sender local-first)',
        () async {
      await local.putBytes(
        key: 'base1/$uuid.png',
        bytes: <int>[9, 9, 9],
        mimeType: 'image/png',
      );

      final uri = await storage.resolveUri(cloudPath);

      expect(uri, startsWith('file://'));
      expect(uri, contains('$uuid.png'));
      expect(cloud.resolveCalls, isEmpty);
    });

    test('cloud key with only HEIC local sibling falls through to download URL',
        () async {
      await local.putBytes(
        key: 'base1/$uuid.heic',
        bytes: <int>[1],
        mimeType: 'image/heic',
      );

      final uri = await storage.resolveUri(cloudPath);

      expect(uri, 'https://example.com/tokenized.jpg');
      expect(cloud.resolveCalls, [cloudPath]);
    });

    test('cloud key with no local sibling uses cloud resolveUri', () async {
      final uri = await storage.resolveUri(cloudPath);

      expect(uri, 'https://example.com/tokenized.jpg');
      expect(cloud.resolveCalls, [cloudPath]);
    });

    test('cloud resolve failures throw (widgets map to broken image)', () async {
      cloud.resolveError = StateError('permission-denied');

      expect(
        () => storage.resolveUri(cloudPath),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('ResolvingMediaStorage put/delete', () {
    test('putBytes and delete delegate to local only', () async {
      const key = 'base1/$uuid.jpg';
      await storage.putBytes(
        key: key,
        bytes: <int>[4, 5],
        mimeType: 'image/jpeg',
      );
      expect(File('${tempDir.path}/media/$key').existsSync(), isTrue);

      await storage.delete(key);
      expect(File('${tempDir.path}/media/$key').existsSync(), isFalse);
    });
  });
}
