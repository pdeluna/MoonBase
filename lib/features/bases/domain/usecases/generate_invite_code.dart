import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/core/usecase.dart';
import 'package:moonbase_skeleton/features/bases/domain/repositories/base_repository.dart';

class GenerateInviteCodeParams {
  const GenerateInviteCodeParams({required this.baseId, required this.requesterUserId});

  final BaseId baseId;
  final UserId requesterUserId;
}

class GenerateInviteCode implements UseCase<String, GenerateInviteCodeParams> {
  const GenerateInviteCode(this.repo);

  final BaseRepository repo;

  @override
  Future<Either<Failure, String>> call(GenerateInviteCodeParams p) =>
      repo.generateInviteCode(baseId: p.baseId, requesterUserId: p.requesterUserId);
}
