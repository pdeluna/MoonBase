import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/core/presentation/failure_presenter.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_type.dart';
import 'package:moonbase_skeleton/features/media/domain/repositories/media_storage.dart';
import 'package:moonbase_skeleton/features/media/presentation/providers/media_providers.dart';
import 'package:moonbase_skeleton/features/media/presentation/widgets/media_tile.dart';
import 'package:moonbase_skeleton/features/media/presentation/widgets/video_thumbnail.dart';

/// Trivial `MediaStorage` stub for widget tests.
class _StubMediaStorage implements MediaStorage {
  _StubMediaStorage(
    this.uri, {
    this.keyedUris,
    this.resolveError,
    this.resolveDelay,
  });

  String uri;
  final Map<String, String>? keyedUris;
  Object? resolveError;
  final Duration? resolveDelay;
  int resolveCallCount = 0;

  @override
  Future<String> putBytes({
    required String key,
    required List<int> bytes,
    required String mimeType,
  }) async =>
      key;

  @override
  Future<String> resolveUri(String key) async {
    resolveCallCount++;
    final delay = resolveDelay;
    if (delay != null) await Future<void>.delayed(delay);
    final err = resolveError;
    if (err != null) throw err;
    return keyedUris?[key] ?? uri;
  }

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

    test('https:// → CachedNetworkImageProvider with stable cacheKey', () {
      const path = 'bases/base1/media/550e8400-e29b-41d4-a716-446655440000.jpg';
      final provider = imageProviderForUri(
        'https://example.com/a.jpg?token=rotating',
        cacheKey: path,
      );
      expect(provider, isA<CachedNetworkImageProvider>());
      final cached = provider as CachedNetworkImageProvider;
      expect(cached.url, 'https://example.com/a.jpg?token=rotating');
      expect(cached.cacheKey, path);
    });

    test('http:// → CachedNetworkImageProvider', () {
      final provider = imageProviderForUri('http://example.com/a.jpg');
      expect(provider, isA<CachedNetworkImageProvider>());
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

  testWidgets(
    'video with thumbnailKey renders poster Image inside VideoThumbnail',
    (tester) async {
      final storage = _StubMediaStorage(
        'file:///tmp/clip.mp4',
        keyedUris: {
          'b1/m3.thumb.jpg': 'file:///tmp/poster.jpg',
        },
      );
      const media = MediaRef(
        id: MediaId('m3'),
        type: MediaType.video,
        storageKey: 'b1/m3.mp4',
        thumbnailKey: 'b1/m3.thumb.jpg',
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

      await tester.pump();

      expect(find.byType(VideoThumbnail), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
    },
  );

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

  testWidgets(
    'resolveUri throw → broken-image fallback (not stuck on placeholder)',
    (tester) async {
      final storage = _StubMediaStorage(
        'https://example.com/x.jpg',
        resolveError: StateError('storage-denied'),
      );
      const media = MediaRef(
        id: MediaId('m-fail'),
        type: MediaType.image,
        storageKey:
            'bases/base1/media/550e8400-e29b-41d4-a716-446655440000.jpg',
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

      await tester.pump();

      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  // -------------------------------------------------------------------------
  // B-b: broken state varies by Failure type and retries on tap.
  // -------------------------------------------------------------------------
  group('MediaTile broken state per Failure', () {
    const media = MediaRef(
      id: MediaId('m-broken'),
      type: MediaType.image,
      storageKey: 'bases/base1/media/550e8400-e29b-41d4-a716-446655440000.jpg',
    );

    Future<_StubMediaStorage> pumpBroken(
      WidgetTester tester,
      Object error, {
      bool showDebugDetails = false,
    }) async {
      final storage = _StubMediaStorage(
        'https://example.com/x.jpg',
        resolveError: error,
      );
      await tester.pumpWidget(ProviderScope(
        overrides: [mediaStorageProvider.overrideWithValue(storage)],
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: MediaTile(
                media: media,
                width: 120,
                height: 120,
                showDebugDetails: showDebugDetails,
              ),
            ),
          ),
        ),
      ));
      await tester.pump();
      return storage;
    }

    testWidgets('NetworkFailure → cloud_off with plain tooltip',
        (tester) async {
      await pumpBroken(tester, const NetworkFailure('retry-limit-exceeded'));
      expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
      expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
      expect(
        find.byTooltip('$kNetworkErrorCopy Tap to retry.'),
        findsOneWidget,
      );
    });

    testWidgets('NetworkTimeoutFailure → cloud_off', (tester) async {
      await pumpBroken(tester, const NetworkTimeoutFailure());
      expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
    });

    testWidgets('PermissionDeniedFailure → lock', (tester) async {
      await pumpBroken(tester, const PermissionDeniedFailure());
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(
          find.byTooltip('Permission denied. Tap to retry.'), findsOneWidget);
    });

    testWidgets('UnauthenticatedFailure → lock', (tester) async {
      await pumpBroken(tester, const UnauthenticatedFailure());
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('MediaNotFoundFailure → broken_image', (tester) async {
      await pumpBroken(tester, const MediaNotFoundFailure());
      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
      expect(
        find.byTooltip('This media is no longer available. Tap to retry.'),
        findsOneWidget,
      );
    });

    testWidgets('non-Failure error → broken_image, no Exception: in tooltip',
        (tester) async {
      await pumpBroken(tester, Exception('weird'));
      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
      expect(find.byTooltip('weird Tap to retry.'), findsOneWidget);
    });

    testWidgets('tap on the broken tile evicts the future and resolves again',
        (tester) async {
      final storage = await pumpBroken(tester, const NetworkFailure());
      expect(storage.resolveCallCount, 1);
      expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);

      // Network is back: the next resolve succeeds with a file:// URI so the
      // test stays hermetic (no HTTP).
      storage.resolveError = null;
      storage.uri = 'file:///tmp/restored.jpg';
      await tester.tap(find.byIcon(Icons.cloud_off_outlined));
      await tester.pump();
      await tester.pump();

      expect(storage.resolveCallCount, 2);
      expect(find.byIcon(Icons.cloud_off_outlined), findsNothing);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('showDebugDetails: true → long-press opens raw details dialog',
        (tester) async {
      await pumpBroken(
        tester,
        const PermissionDeniedFailure(),
        showDebugDetails: true,
      );
      // Debug builds drop the user Tooltip (long-press is taken by details).
      expect(find.byTooltip('Permission denied. Tap to retry.'), findsNothing);
      await tester.longPress(find.byIcon(Icons.lock_outline));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.textContaining('type: PermissionDeniedFailure'),
        findsOneWidget,
      );
    });

    testWidgets('showDebugDetails: false → long-press shows no dialog',
        (tester) async {
      await pumpBroken(tester, const PermissionDeniedFailure());
      await tester.longPress(find.byIcon(Icons.lock_outline));
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(AlertDialog), findsNothing);
    });

    test('MediaBrokenTile.iconFor mapping table', () {
      expect(MediaBrokenTile.iconFor(const NetworkFailure()),
          Icons.cloud_off_outlined);
      expect(MediaBrokenTile.iconFor(const NetworkTimeoutFailure()),
          Icons.cloud_off_outlined);
      expect(MediaBrokenTile.iconFor(const PermissionDeniedFailure()),
          Icons.lock_outline);
      expect(MediaBrokenTile.iconFor(const UnauthenticatedFailure()),
          Icons.lock_outline);
      expect(MediaBrokenTile.iconFor(const MediaNotFoundFailure()),
          Icons.broken_image_outlined);
      expect(MediaBrokenTile.iconFor(const UnknownFailure()),
          Icons.broken_image_outlined);
      expect(MediaBrokenTile.iconFor(null), Icons.broken_image_outlined);
    });
  });

  testWidgets(
    'parent rebuilds do not restart resolveUri (stable Future)',
    (tester) async {
      final storage = _StubMediaStorage(
        'file:///tmp/stable.jpg',
        resolveDelay: const Duration(milliseconds: 50),
      );
      const media = MediaRef(
        id: MediaId('m-stable'),
        type: MediaType.image,
        storageKey:
            'bases/base1/media/550e8400-e29b-41d4-a716-446655440000.jpg',
      );

      late VoidCallback triggerRebuild;
      await tester.pumpWidget(ProviderScope(
        overrides: [mediaStorageProvider.overrideWithValue(storage)],
        child: MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                // Keep the same MediaTile Element across chat-like rebuilds.
                triggerRebuild = () => setState(() {});
                return const Center(
                  child: MediaTile(media: media, width: 120, height: 120),
                );
              },
            ),
          ),
        ),
      ));

      await tester.pump();
      triggerRebuild();
      await tester.pump();
      triggerRebuild();
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 60));

      expect(storage.resolveCallCount, 1);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );
}
