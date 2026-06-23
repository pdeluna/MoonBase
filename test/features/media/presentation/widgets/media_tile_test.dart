import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_type.dart';
import 'package:moonbase_skeleton/features/media/domain/repositories/media_storage.dart';
import 'package:moonbase_skeleton/features/media/presentation/providers/media_providers.dart';
import 'package:moonbase_skeleton/features/media/presentation/widgets/media_tile.dart';
import 'package:moonbase_skeleton/features/media/presentation/widgets/video_thumbnail.dart';

/// Trivial `MediaStorage` stub for widget tests.
class _StubMediaStorage implements MediaStorage {
  _StubMediaStorage(this.uri);
  final String uri;

  @override
  Future<String> putBytes({
    required String key,
    required List<int> bytes,
    required String mimeType,
  }) async =>
      key;

  @override
  Future<String> resolveUri(String key) async => uri;

  @override
  Future<void> delete(String key) async {}
}

void main() {
  // -------------------------------------------------------------------------
  // Pure scheme → ImageProvider dispatch (covers DoD T0.1 "renders image for
  // `file://` and `https://` schemes"). Testing this as a unit keeps the
  // widget test suite hermetic — `Image.file` and `Image.network` would
  // otherwise schedule real decode/HTTP work that leaks across tests.
  // -------------------------------------------------------------------------
  group('imageProviderForUri', () {
    test('file:// → FileImage with the decoded path', () {
      final provider = imageProviderForUri('file:///tmp/x.png');
      expect(provider, isA<FileImage>());
      // toFilePath normalizes the URI to the platform's native path. On
      // POSIX this is `/tmp/x.png`; on Windows it would prepend a drive.
      // We just assert it round-trips by checking the file name suffix.
      expect((provider as FileImage).file.path, endsWith('x.png'));
    });

    test('https:// → NetworkImage preserving the URL', () {
      final provider = imageProviderForUri('https://example.com/a.jpg');
      expect(provider, isA<NetworkImage>());
      expect((provider as NetworkImage).url, 'https://example.com/a.jpg');
    });

    test('http:// → NetworkImage preserving the URL', () {
      final provider = imageProviderForUri('http://example.com/a.jpg');
      expect(provider, isA<NetworkImage>());
    });

    test('schemeless paths fall back to FileImage on the raw string', () {
      final provider = imageProviderForUri('/var/data/x.png');
      expect(provider, isA<FileImage>());
      expect((provider as FileImage).file.path, '/var/data/x.png');
    });
  });

  // -------------------------------------------------------------------------
  // Widget-level smoke for the video branch: no Image is constructed, so no
  // decode/HTTP work is scheduled and the test is fully synchronous.
  // -------------------------------------------------------------------------
  testWidgets('MediaTile renders VideoThumbnail (and no Image) for video type',
      (tester) async {
    final storage = _StubMediaStorage('file:///tmp/clip.mp4');
    const media = MediaRef(
      id: MediaId('m3'),
      type: MediaType.video,
      storageKey: 'b1/m3.mp4',
      duration: Duration(seconds: 12),
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [mediaStorageProvider.overrideWithValue(storage)],
      child: const MaterialApp(
        home: Scaffold(
          body: Center(
            child: MediaTile(media: media, width: 120, height: 120),
          ),
        ),
      ),
    ));

    // FutureBuilder resolves on the next microtask flush.
    await tester.pump();

    expect(find.byType(VideoThumbnail), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('MediaTile.onTap fires when the tile is tapped', (tester) async {
    final storage = _StubMediaStorage('file:///tmp/clip.mp4');
    const media = MediaRef(
      id: MediaId('m4'),
      type: MediaType.video,
      storageKey: 'b1/m4.mp4',
    );

    var taps = 0;
    await tester.pumpWidget(ProviderScope(
      overrides: [mediaStorageProvider.overrideWithValue(storage)],
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: MediaTile(
              media: media,
              width: 100,
              height: 100,
              onTap: () => taps++,
            ),
          ),
        ),
      ),
    ));

    await tester.pump();
    await tester.tap(find.byType(MediaTile));
    expect(taps, 1);
  });
}
