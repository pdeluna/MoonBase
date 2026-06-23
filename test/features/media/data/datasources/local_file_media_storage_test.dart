import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:moonbase_skeleton/features/media/data/datasources/local_file_media_storage.dart';

void main() {
  late Directory tempDir;
  late LocalFileMediaStorage storage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mb_local_storage_test_');
    storage = LocalFileMediaStorage(tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('LocalFileMediaStorage round-trip', () {
    test('putBytes writes under <docsDir>/media/<key> and returns the key',
        () async {
      const key = 'base-1/abcd-1234.png';
      final bytes = <int>[1, 2, 3, 4, 5];

      final returned = await storage.putBytes(
        key: key,
        bytes: bytes,
        mimeType: 'image/png',
      );

      expect(returned, key);
      final onDisk = File('${tempDir.path}/media/$key');
      expect(await onDisk.exists(), isTrue);
      expect(await onDisk.readAsBytes(), bytes);
    });

    test('resolveUri returns a file:// URI for an existing key', () async {
      const key = 'base-1/abcd-1234.png';
      await storage.putBytes(key: key, bytes: <int>[7], mimeType: 'image/png');

      final uri = await storage.resolveUri(key);

      expect(uri, startsWith('file://'));
      final parsed = Uri.parse(uri);
      expect(parsed.scheme, 'file');
      expect(File(parsed.toFilePath()).existsSync(), isTrue);
    });

    test('resolveUri returns a stable URI even before put (lazy resolution)',
        () async {
      // The contract is "resolve a key to a URI"; the file does not need to
      // exist yet (think: rendering a card immediately after a write that
      // hasn't yet flushed). Existence is the widget's concern.
      final uri = await storage.resolveUri('base-x/never-written.jpg');

      expect(uri, startsWith('file://'));
    });

    test('delete removes the underlying file', () async {
      const key = 'base-1/to-delete.png';
      await storage.putBytes(
        key: key,
        bytes: <int>[1, 2, 3],
        mimeType: 'image/png',
      );
      final onDisk = File('${tempDir.path}/media/$key');
      expect(await onDisk.exists(), isTrue);

      await storage.delete(key);

      expect(await onDisk.exists(), isFalse);
    });

    test('delete is a no-op for unknown keys', () async {
      // Should not throw.
      await storage.delete('base-1/never-existed.png');
    });

    test('putBytes creates the base-scoped subdirectory on first write',
        () async {
      const key = 'fresh-base/first.png';
      await storage.putBytes(
        key: key,
        bytes: <int>[9],
        mimeType: 'image/png',
      );

      expect(Directory('${tempDir.path}/media/fresh-base').existsSync(),
          isTrue);
    });

    test('rejects absolute keys (would escape the media root)', () async {
      expect(
        () => storage.putBytes(
          key: '/etc/passwd',
          bytes: const <int>[0],
          mimeType: 'text/plain',
        ),
        throwsArgumentError,
      );
    });

    test('rejects path-traversal keys', () async {
      expect(
        () => storage.putBytes(
          key: '../outside.png',
          bytes: const <int>[0],
          mimeType: 'image/png',
        ),
        throwsArgumentError,
      );
    });
  });
}
