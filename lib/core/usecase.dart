import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';

abstract class UseCase<Out, In> {
  Future<Either<Failure, Out>> call(In params);
}

class NoParams { const NoParams(); }