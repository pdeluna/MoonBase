import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/error_mapper.dart';
import 'package:moonbase_skeleton/core/failure.dart';

void main() {
  group('guardWithTimeout', () {
    test('never-completing future yields Left(NetworkTimeoutFailure)', () {
      fakeAsync((async) {
        late Either<Failure, int> result;
        guardWithTimeout(() => Completer<int>().future).then((r) => result = r);

        async.elapse(kGuardTimeout);
        async.flushMicrotasks();

        expect(result, isA<Left<Failure, int>>());
        expect(
          result.match((f) => f, (_) => fail('expected Left')),
          isA<NetworkTimeoutFailure>(),
        );
      });
    });

    test('completing normally is unaffected', () async {
      final result = await guardWithTimeout(() async => 7);
      expect(result, const Right<Failure, int>(7));
    });

    test('completing at 18s still succeeds', () {
      fakeAsync((async) {
        final completer = Completer<int>();
        late Either<Failure, int> result;
        guardWithTimeout(() => completer.future).then((r) => result = r);

        async.elapse(const Duration(seconds: 18));
        completer.complete(7);
        async.flushMicrotasks();

        expect(result, const Right<Failure, int>(7));
      });
    });
  });
}
