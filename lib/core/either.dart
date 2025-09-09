/// Either<L, R>: Left for failure, Right for success.
sealed class Either<L, R> {
  const Either();

  /// Applies the appropriate function based on whether this is a Left or Right.
  T match<T>(T Function(L l) left, T Function(R r) right);

  bool get isLeft => this is Left<L, R>;
  bool get isRight => this is Right<L, R>;

  /// Alias for `match`.
  T fold<T>(T Function(L l) left, T Function(R r) right) => match(left, right);

  /// Returns the right value or computes a default.
  R getOrElse(R Function() orElse) => match((_) => orElse(), (r) => r);

  /// Map the Right value.
  Either<L, R2> map<R2>(R2 Function(R r) f) =>
      match((l) => Left<L, R2>(l), (r) => Right<L, R2>(f(r)));

  /// Map the Left value.
  Either<L2, R> mapLeft<L2>(L2 Function(L l) f) =>
      match((l) => Left<L2, R>(f(l)), (r) => Right<L2, R>(r));
}

/// Left: typically error/failure.
class Left<L, R> extends Either<L, R> {
  final L value;
  const Left(this.value);

  @override
  T match<T>(T Function(L l) left, T Function(R r) right) => left(value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Left<L, R> && other.value == value);

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Left($value)';
}

/// Right: typically success.
class Right<L, R> extends Either<L, R> {
  final R value;
  const Right(this.value);

  @override
  T match<T>(T Function(L l) left, T Function(R r) right) => right(value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Right<L, R> && other.value == value);

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Right($value)';
}
