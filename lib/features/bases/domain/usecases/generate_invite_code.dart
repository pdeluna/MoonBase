import '../../../../core/either.dart';
import '../../../../core/failure.dart';
import '../../../../core/usecase.dart';
import '../repositories/base_repository.dart';

class GenerateInviteCodeParams {
  final String baseId;
  final String requesterUserId;
  const GenerateInviteCodeParams({required this.baseId, required this.requesterUserId});
}

class GenerateInviteCode implements UseCase<String, GenerateInviteCodeParams> {
  final BaseRepository repo;
  const GenerateInviteCode(this.repo);

  @override
  Future<Either<Failure, String>> call(GenerateInviteCodeParams p) =>
      repo.generateInviteCode(baseId: p.baseId, requesterUserId: p.requesterUserId);
}
