import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_pick_request.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_type.dart';
import 'package:moonbase_skeleton/features/media/domain/repositories/media_picker.dart';
import 'package:moonbase_skeleton/features/media/domain/usecases/pick_and_persist_multiple_images.dart';

class _MockMediaPicker extends Mock implements MediaPicker {}

class _FakeMediaPickRequest extends Fake implements MediaPickRequest {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeMediaPickRequest());
  });

  late _MockMediaPicker picker;
  late PickAndPersistMultipleImages useCase;
  const baseId = BaseId('b1');

  setUp(() {
    picker = _MockMediaPicker();
    useCase = PickAndPersistMultipleImages(picker);
  });

  MediaRef imageRef(String id) => MediaRef(
        id: MediaId(id),
        type: MediaType.image,
        storageKey: 'b1/$id.png',
      );

  test('delegates to picker.pickMultipleImages with limit', () async {
    when(
      () => picker.pickMultipleImages(any(), limit: any(named: 'limit')),
    ).thenAnswer((_) async => [imageRef('m1'), imageRef('m2')]);

    final res = await useCase(
      const PickMultipleImagesParams(
        request: MediaPickRequest(
          baseId: baseId,
          kind: MediaType.image,
          source: MediaSource.gallery,
        ),
        limit: 3,
      ),
    );

    expect(res, isA<Right<Failure, List<MediaRef>>>());
    res.match((_) => fail('expected success'), (refs) {
      expect(refs, hasLength(2));
    });
    verify(
      () => picker.pickMultipleImages(any(), limit: 3),
    ).called(1);
  });

  test('user cancel surfaces as Right([])', () async {
    when(
      () => picker.pickMultipleImages(any(), limit: any(named: 'limit')),
    ).thenAnswer((_) async => []);

    final res = await useCase(
      const PickMultipleImagesParams(
        request: MediaPickRequest(
          baseId: baseId,
          kind: MediaType.image,
          source: MediaSource.gallery,
        ),
        limit: 4,
      ),
    );

    res.match((_) => fail('cancel must not be a failure'), (refs) {
      expect(refs, isEmpty);
    });
  });

  test('MediaTooLargeFailure surfaces as Left', () async {
    when(
      () => picker.pickMultipleImages(any(), limit: any(named: 'limit')),
    ).thenThrow(const MediaTooLargeFailure());

    final res = await useCase(
      const PickMultipleImagesParams(
        request: MediaPickRequest(
          baseId: baseId,
          kind: MediaType.image,
          source: MediaSource.gallery,
        ),
        limit: 2,
      ),
    );

    expect(res, isA<Left<Failure, List<MediaRef>>>());
  });
}
