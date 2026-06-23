import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/features/media/domain/repositories/media_storage.dart';
import 'package:moonbase_skeleton/features/media/domain/usecases/delete_media.dart';

class _MockMediaStorage extends Mock implements MediaStorage {}

void main() {
  late _MockMediaStorage storage;
  late DeleteMedia useCase;

  setUp(() {
    storage = _MockMediaStorage();
    useCase = DeleteMedia(storage);
  });

  test('delegates to storage.delete with the supplied key', () async {
    when(() => storage.delete(any())).thenAnswer((_) async {});

    final result = await useCase('b1/m1.png');

    expect(result, isA<Right<Failure, Unit>>());
    verify(() => storage.delete('b1/m1.png')).called(1);
  });

  test('storage I/O error surfaces as a Left(Failure)', () async {
    when(() => storage.delete(any()))
        .thenThrow(StateError('disk unavailable'));

    final result = await useCase('b1/m1.png');

    expect(result, isA<Left<Failure, Unit>>());
  });
}
