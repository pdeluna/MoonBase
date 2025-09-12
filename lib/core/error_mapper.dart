import 'dart:async';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/either.dart';

Failure mapException(Object e) {
  if (e is TimeoutException) return const NetworkFailure('Timeout');
  if (e is StateError || e is FormatException) return const CacheFailure('Local data error');
  return UnknownFailure(e.toString());
}

Future<Either<Failure, T>> guard<T>(Future<T> Function() run) async {
  try {
    final v = await run();
    return Right(v);
  } catch (e) {
    return Left(mapException(e));
  }
}

/// Use this when your Right type is `void`.
Future<Either<Failure, void>> guardVoid(Future<void> Function() run) async {
  try {
    await run();
    return const Right(null);
  } catch (e) {
    return Left(mapException(e));
  }
}
