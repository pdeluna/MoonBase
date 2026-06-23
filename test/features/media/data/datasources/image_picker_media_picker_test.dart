import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';

import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/media/data/datasources/image_picker_media_picker.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_constraints.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_pick_request.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_type.dart';
import 'package:moonbase_skeleton/features/media/domain/repositories/media_storage.dart';

class _MockImagePicker extends Mock implements ImagePicker {}

class _MockMediaStorage extends Mock implements MediaStorage {}

/// 1x1 transparent PNG. Real magic bytes so `mime.lookupMimeType` reports
/// `image/png` instead of falling back to the default.
final Uint8List _tinyPng = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

/// Minimal MP4 header that `package:mime` recognizes as `video/mp4`.
/// Contains the `ftyp` box with major brand `isom`.
final Uint8List _tinyMp4 = Uint8List.fromList(<int>[
  0x00, 0x00, 0x00, 0x20, 0x66, 0x74, 0x79, 0x70, // ....ftyp
  0x69, 0x73, 0x6F, 0x6D, 0x00, 0x00, 0x02, 0x00, // isom....
  0x69, 0x73, 0x6F, 0x6D, 0x69, 0x73, 0x6F, 0x32, // isomiso2
  0x61, 0x76, 0x63, 0x31, 0x6D, 0x70, 0x34, 0x31, // avc1mp41
  0x00, 0x00, 0x00, 0x08, 0x6D, 0x64, 0x61, 0x74, // ....mdat
]);

Future<Uint8List> _strictByteCap({
  required XFile source,
  required Uint8List bytes,
  required int maxBytes,
}) async {
  if (bytes.length > maxBytes) throw const MediaTooLargeFailure();
  return bytes;
}

void main() {
  late Directory tempDir;
  late _MockImagePicker mockImagePicker;
  late _MockMediaStorage mockStorage;
  late BaseId baseId;
  int idCounter = 0;

  setUpAll(() {
    // Mocktail needs a fallback instance for any non-nullable type used with
    // `any()` / `captureAny()`. Both args show up in our `verify*` calls.
    registerFallbackValue(ImageSource.gallery);
    registerFallbackValue(const Duration(seconds: 30));
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mb_picker_test_');
    mockImagePicker = _MockImagePicker();
    mockStorage = _MockMediaStorage();
    baseId = const BaseId('base-1');
    idCounter = 0;

    // Storage always echoes back the canonical key (matches the
    // LocalFileMediaStorage contract). Picker tests don't care where bytes
    // land; storage I/O is exercised in local_file_media_storage_test.
    when(() => mockStorage.putBytes(
          key: any(named: 'key'),
          bytes: any(named: 'bytes'),
          mimeType: any(named: 'mimeType'),
        )).thenAnswer((inv) async => inv.namedArguments[#key] as String);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  ImagePickerMediaPicker buildPicker({
    MediaConstraints constraints = MediaConstraints.defaults,
    VideoDurationProbe? videoDurationProbe,
    ImageByteNormalizer? imageByteNormalizer,
  }) {
    return ImagePickerMediaPicker(
      storage: mockStorage,
      constraints: constraints,
      imagePicker: mockImagePicker,
      videoDurationProbe: videoDurationProbe,
      imageByteNormalizer: imageByteNormalizer ?? _strictByteCap,
      idGenerator: () => 'media-${++idCounter}',
    );
  }

  Future<File> writeFile(String name, List<int> bytes) async {
    final f = File('${tempDir.path}/$name');
    await f.writeAsBytes(bytes, flush: true);
    return f;
  }

  group('cancel behaviour', () {
    test('pickImage returns null when ImagePicker returns null', () async {
      when(() => mockImagePicker.pickImage(source: ImageSource.gallery))
          .thenAnswer((_) async => null);

      final result = await buildPicker().pickImage(
        MediaPickRequest(
          baseId: baseId,
          kind: MediaType.image,
          source: MediaSource.gallery,
        ),
      );

      expect(result, isNull);
      verifyNever(() => mockStorage.putBytes(
            key: any(named: 'key'),
            bytes: any(named: 'bytes'),
            mimeType: any(named: 'mimeType'),
          ));
    });

    test('pickVideo returns null when ImagePicker returns null', () async {
      when(() => mockImagePicker.pickVideo(
            source: ImageSource.gallery,
            maxDuration: any(named: 'maxDuration'),
          )).thenAnswer((_) async => null);

      final result = await buildPicker().pickVideo(
        MediaPickRequest(
          baseId: baseId,
          kind: MediaType.video,
          source: MediaSource.gallery,
        ),
      );

      expect(result, isNull);
    });

    test('captureFromCamera returns null when ImagePicker returns null',
        () async {
      when(() => mockImagePicker.pickImage(source: ImageSource.camera))
          .thenAnswer((_) async => null);

      final result = await buildPicker().captureFromCamera(
        MediaPickRequest(
          baseId: baseId,
          kind: MediaType.image,
          source: MediaSource.camera,
        ),
      );

      expect(result, isNull);
    });
  });

  group('captureFromCamera dispatches by kind', () {
    test('image kind → pickImage(source: camera)', () async {
      final file = await writeFile('shot.png', _tinyPng);
      when(() => mockImagePicker.pickImage(source: ImageSource.camera))
          .thenAnswer((_) async => XFile(file.path));

      final result = await buildPicker().captureFromCamera(
        MediaPickRequest(
          baseId: baseId,
          kind: MediaType.image,
          source: MediaSource.camera,
        ),
      );

      expect(result, isA<MediaRef>());
      expect(result!.type, MediaType.image);
      verify(() => mockImagePicker.pickImage(source: ImageSource.camera))
          .called(1);
      verifyNever(() => mockImagePicker.pickVideo(
            source: any(named: 'source'),
            maxDuration: any(named: 'maxDuration'),
          ));
    });

    test('video kind → pickVideo(source: camera, maxDuration: ...)', () async {
      final file = await writeFile('shot.mp4', _tinyMp4);
      when(() => mockImagePicker.pickVideo(
            source: ImageSource.camera,
            maxDuration: any(named: 'maxDuration'),
          )).thenAnswer((_) async => XFile(file.path));

      final result = await buildPicker().captureFromCamera(
        MediaPickRequest(
          baseId: baseId,
          kind: MediaType.video,
          source: MediaSource.camera,
        ),
      );

      expect(result, isA<MediaRef>());
      expect(result!.type, MediaType.video);
      verify(() => mockImagePicker.pickVideo(
            source: ImageSource.camera,
            maxDuration:
                MediaConstraints.defaults.videoMaxDuration,
          )).called(1);
      verifyNever(
          () => mockImagePicker.pickImage(source: any(named: 'source')));
    });
  });

  group('byte cap enforcement', () {
    const tinyCaps = MediaConstraints(
      imageMaxBytes: 16, // anything > 16 bytes is too large
      videoMaxBytes: 16,
      videoMaxDuration: Duration(seconds: 30),
    );

    test('pickImage throws MediaTooLargeFailure when over cap', () async {
      // _tinyPng is ~70 bytes, comfortably over the 16-byte cap.
      final file = await writeFile('big.png', _tinyPng);
      when(() => mockImagePicker.pickImage(source: ImageSource.gallery))
          .thenAnswer((_) async => XFile(file.path));

      await expectLater(
        buildPicker(constraints: tinyCaps).pickImage(MediaPickRequest(
          baseId: baseId,
          kind: MediaType.image,
          source: MediaSource.gallery,
        )),
        throwsA(isA<MediaTooLargeFailure>()),
      );
    });

    test('pickVideo throws MediaTooLargeFailure when over cap', () async {
      final file = await writeFile('big.mp4', _tinyMp4);
      when(() => mockImagePicker.pickVideo(
            source: ImageSource.gallery,
            maxDuration: any(named: 'maxDuration'),
          )).thenAnswer((_) async => XFile(file.path));

      await expectLater(
        buildPicker(constraints: tinyCaps).pickVideo(MediaPickRequest(
          baseId: baseId,
          kind: MediaType.video,
          source: MediaSource.gallery,
        )),
        throwsA(isA<MediaTooLargeFailure>()),
      );
    });

    test('captureFromCamera throws MediaTooLargeFailure when over cap',
        () async {
      final file = await writeFile('big.png', _tinyPng);
      when(() => mockImagePicker.pickImage(source: ImageSource.camera))
          .thenAnswer((_) async => XFile(file.path));

      await expectLater(
        buildPicker(constraints: tinyCaps)
            .captureFromCamera(MediaPickRequest(
          baseId: baseId,
          kind: MediaType.image,
          source: MediaSource.camera,
        )),
        throwsA(isA<MediaTooLargeFailure>()),
      );
    });
    test('pickMultipleImages throws MediaTooLargeFailure when any file over cap',
        () async {
      final file = await writeFile('big.png', _tinyPng);
      when(() => mockImagePicker.pickMultiImage(limit: any(named: 'limit')))
          .thenAnswer((_) async => [XFile(file.path)]);

      await expectLater(
        buildPicker(constraints: tinyCaps).pickMultipleImages(
          MediaPickRequest(
            baseId: baseId,
            kind: MediaType.image,
            source: MediaSource.gallery,
          ),
          limit: 2,
        ),
        throwsA(isA<MediaTooLargeFailure>()),
      );
    });
  });

  group('multi-image pick', () {
    test('returns one ref per picked file and forwards limit to OS picker',
        () async {
      final f1 = await writeFile('a.png', _tinyPng);
      final f2 = await writeFile('b.png', _tinyPng);
      when(() => mockImagePicker.pickMultiImage(limit: 3)).thenAnswer(
        (_) async => [XFile(f1.path), XFile(f2.path)],
      );

      final result = await buildPicker().pickMultipleImages(
        MediaPickRequest(
          baseId: baseId,
          kind: MediaType.image,
          source: MediaSource.gallery,
        ),
        limit: 3,
      );

      expect(result, hasLength(2));
      expect(result.every((r) => r.type == MediaType.image), isTrue);
      verify(() => mockImagePicker.pickMultiImage(limit: 3)).called(1);
      verify(() => mockStorage.putBytes(
            key: any(named: 'key'),
            bytes: any(named: 'bytes'),
            mimeType: any(named: 'mimeType'),
          )).called(2);
    });

    test('returns empty list when user cancels gallery multi-select', () async {
      when(() => mockImagePicker.pickMultiImage(limit: any(named: 'limit')))
          .thenAnswer((_) async => []);

      final result = await buildPicker().pickMultipleImages(
        MediaPickRequest(
          baseId: baseId,
          kind: MediaType.image,
          source: MediaSource.gallery,
        ),
        limit: 4,
      );

      expect(result, isEmpty);
      verifyNever(() => mockStorage.putBytes(
            key: any(named: 'key'),
            bytes: any(named: 'bytes'),
            mimeType: any(named: 'mimeType'),
          ));
    });
  });

  group('duration cap enforcement', () {
    test(
        'pickVideo throws MediaTooLongFailure when probed duration > 30s',
        () async {
      final file = await writeFile('long.mp4', _tinyMp4);
      when(() => mockImagePicker.pickVideo(
            source: ImageSource.gallery,
            maxDuration: any(named: 'maxDuration'),
          )).thenAnswer((_) async => XFile(file.path));

      final picker = buildPicker(
        videoDurationProbe: (_) async => const Duration(seconds: 60),
      );

      await expectLater(
        picker.pickVideo(MediaPickRequest(
          baseId: baseId,
          kind: MediaType.video,
          source: MediaSource.gallery,
        )),
        throwsA(isA<MediaTooLongFailure>()),
      );
    });

    test(
        'captureFromCamera (video) throws MediaTooLongFailure when probed > 30s',
        () async {
      final file = await writeFile('long.mp4', _tinyMp4);
      when(() => mockImagePicker.pickVideo(
            source: ImageSource.camera,
            maxDuration: any(named: 'maxDuration'),
          )).thenAnswer((_) async => XFile(file.path));

      final picker = buildPicker(
        videoDurationProbe: (_) async => const Duration(seconds: 60),
      );

      await expectLater(
        picker.captureFromCamera(MediaPickRequest(
          baseId: baseId,
          kind: MediaType.video,
          source: MediaSource.camera,
        )),
        throwsA(isA<MediaTooLongFailure>()),
      );
    });
  });

  group('happy path persistence', () {
    test('pickImage writes through storage with base-scoped key', () async {
      final file = await writeFile('photo.png', _tinyPng);
      when(() => mockImagePicker.pickImage(source: ImageSource.gallery))
          .thenAnswer((_) async => XFile(file.path));

      final ref = await buildPicker().pickImage(MediaPickRequest(
        baseId: baseId,
        kind: MediaType.image,
        source: MediaSource.gallery,
      ));

      expect(ref, isNotNull);
      expect(ref!.type, MediaType.image);
      expect(ref.storageKey, 'base-1/media-1.png');
      expect(ref.sizeBytes, _tinyPng.length);
      expect(ref.mimeType, 'image/png');

      final captured = verify(() => mockStorage.putBytes(
            key: captureAny(named: 'key'),
            bytes: captureAny(named: 'bytes'),
            mimeType: captureAny(named: 'mimeType'),
          )).captured;
      expect(captured[0], 'base-1/media-1.png');
      expect(captured[1], _tinyPng);
      expect(captured[2], 'image/png');
    });
  });
}
