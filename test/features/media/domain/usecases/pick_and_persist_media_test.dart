import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_pick_request.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_type.dart';
import 'package:moonbase_skeleton/features/media/domain/repositories/media_picker.dart';
import 'package:moonbase_skeleton/features/media/domain/usecases/pick_and_persist_media.dart';

class _MockMediaPicker extends Mock implements MediaPicker {}

class _FakeMediaPickRequest extends Fake implements MediaPickRequest {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeMediaPickRequest());
  });

  late _MockMediaPicker picker;
  late PickAndPersistMedia useCase;
  const baseId = BaseId('b1');

  setUp(() {
    picker = _MockMediaPicker();
    useCase = PickAndPersistMedia(picker);
  });

  MediaRef imageRef() => const MediaRef(
        id: MediaId('m1'),
        type: MediaType.image,
        storageKey: 'b1/m1.png',
      );

  MediaRef videoRef() => const MediaRef(
        id: MediaId('m2'),
        type: MediaType.video,
        storageKey: 'b1/m2.mp4',
      );

  group('dispatch', () {
    test('gallery + image → picker.pickImage', () async {
      when(() => picker.pickImage(any())).thenAnswer((_) async => imageRef());

      final res = await useCase(const MediaPickRequest(
        baseId: baseId,
        kind: MediaType.image,
        source: MediaSource.gallery,
      ));

      expect(res, isA<Right<Failure, MediaRef?>>());
      verify(() => picker.pickImage(any())).called(1);
      verifyNever(() => picker.pickVideo(any()));
      verifyNever(() => picker.captureFromCamera(any()));
    });

    test('gallery + video → picker.pickVideo', () async {
      when(() => picker.pickVideo(any())).thenAnswer((_) async => videoRef());

      final res = await useCase(const MediaPickRequest(
        baseId: baseId,
        kind: MediaType.video,
        source: MediaSource.gallery,
      ));

      expect(res, isA<Right<Failure, MediaRef?>>());
      verify(() => picker.pickVideo(any())).called(1);
      verifyNever(() => picker.pickImage(any()));
    });

    test('camera (any kind) → picker.captureFromCamera', () async {
      when(() => picker.captureFromCamera(any()))
          .thenAnswer((_) async => imageRef());

      final res = await useCase(const MediaPickRequest(
        baseId: baseId,
        kind: MediaType.image,
        source: MediaSource.camera,
      ));

      expect(res, isA<Right<Failure, MediaRef?>>());
      verify(() => picker.captureFromCamera(any())).called(1);
    });
  });

  group('result mapping', () {
    test('user cancel surfaces as Right(null), not a failure', () async {
      when(() => picker.pickImage(any())).thenAnswer((_) async => null);

      final res = await useCase(const MediaPickRequest(
        baseId: baseId,
        kind: MediaType.image,
        source: MediaSource.gallery,
      ));

      expect(res, isA<Right<Failure, MediaRef?>>());
      res.match((_) => fail('cancel must not be a failure'), (r) {
        expect(r, isNull);
      });
    });

    test('typed Failure thrown by picker surfaces as Left', () async {
      when(() => picker.pickImage(any()))
          .thenThrow(const MediaTooLargeFailure());

      final res = await useCase(const MediaPickRequest(
        baseId: baseId,
        kind: MediaType.image,
        source: MediaSource.gallery,
      ));

      expect(res, isA<Left<Failure, MediaRef?>>());
      res.match(
        (failure) => expect(failure, isA<MediaTooLargeFailure>()),
        (_) => fail('should not succeed'),
      );
    });

    test('arbitrary exception surfaces as UnknownFailure', () async {
      when(() => picker.pickImage(any()))
          .thenThrow(StateError('boom'));

      final res = await useCase(const MediaPickRequest(
        baseId: baseId,
        kind: MediaType.image,
        source: MediaSource.gallery,
      ));

      expect(res, isA<Left<Failure, MediaRef?>>());
      res.match(
        (failure) => expect(failure, isA<UnknownFailure>()),
        (_) => fail('should not succeed'),
      );
    });
  });
}
