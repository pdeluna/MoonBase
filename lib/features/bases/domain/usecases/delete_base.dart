import '../../../../core/either.dart';
import '../../../../core/failure.dart';
import '../../../../core/usecase.dart';
import '../repositories/base_repository.dart';

class DeleteBaseParams {
  final String baseId;
  final String requesterUserId;
  const DeleteBaseParams({required this.baseId, required this.requesterUserId});
}

class DeleteBase implements UseCase<void, DeleteBaseParams> {
  final BaseRepository repo;
  const DeleteBase(this.repo);

  @override
  Future<Either<Failure, void>> call(DeleteBaseParams p) =>
      repo.deleteBase(baseId: p.baseId, requesterUserId: p.requesterUserId);
}
