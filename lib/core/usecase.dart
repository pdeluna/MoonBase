import 'either.dart';
import 'failure.dart';

abstract class UseCase<Out, In> {
  Future<Either<Failure, Out>> call(In params);
}

class NoParams { const NoParams(); }