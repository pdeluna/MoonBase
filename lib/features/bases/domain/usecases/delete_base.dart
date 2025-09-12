import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/core/usecase.dart';
import 'package:moonbase_skeleton/features/bases/domain/repositories/base_repository.dart';

class DeleteBaseParams {
  const DeleteBaseParams({required this.baseId, required this.requesterUserId});

  final BaseId baseId;
  final UserId requesterUserId;
}

class DeleteBase implements UseCase<void, DeleteBaseParams> {
  const DeleteBase(this.repo);

  final BaseRepository repo;

  @override
  Future<Either<Failure, void>> call(DeleteBaseParams p) =>
      repo.deleteBase(baseId: p.baseId, requesterUserId: p.requesterUserId);
}
