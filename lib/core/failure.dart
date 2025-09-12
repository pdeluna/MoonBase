abstract class Failure {
  const Failure(this.message);

  final String message;

  @override
  String toString() => '$runtimeType($message)';
}
class NetworkFailure extends Failure { const NetworkFailure([super.message = 'Network error']); }
class CacheFailure   extends Failure { const CacheFailure([super.message = 'Cache error']); }
class UnknownFailure extends Failure { const UnknownFailure([super.message = 'Unknown error']); }
