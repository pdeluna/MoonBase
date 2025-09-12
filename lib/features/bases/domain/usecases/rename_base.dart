import '../../../../core/either.dart';
import '../../../../core/failure.dart';
import '../../../../core/usecase.dart';
import '../repositories/base_repository.dart';

class RenameBaseParams {
  final String baseId;
  final String newName;
  final String requesterUserId;
  const RenameBaseParams({required this.baseId, required this.newName, required this.requesterUserId});
}

class RenameBase implements UseCase<void, RenameBaseParams> {
  final BaseRepository repo;
  const RenameBase(this.repo);

  @override
  Future<Either<Failure, void>> call(RenameBaseParams p) =>
      repo.renameBase(baseId: p.baseId, newName: p.newName, requesterUserId: p.requesterUserId);
}
