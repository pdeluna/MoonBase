import '../../../../core/either.dart';
import '../../../../core/failure.dart';
import '../../../../core/usecase.dart';
import '../entities/base.dart';
import '../repositories/base_repository.dart';

class JoinBaseParams {
  final String inviteCode;
  final String userId;
  const JoinBaseParams({required this.inviteCode, required this.userId});
}

class JoinBase implements UseCase<Base, JoinBaseParams> {
  final BaseRepository repo;
  const JoinBase(this.repo);

  @override
  Future<Either<Failure, Base>> call(JoinBaseParams p) =>
      repo.joinBase(inviteCode: p.inviteCode, userId: p.userId);
}
