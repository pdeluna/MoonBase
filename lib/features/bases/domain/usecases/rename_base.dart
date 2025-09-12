import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/core/usecase.dart';
import 'package:moonbase_skeleton/core/validators.dart';
import 'package:moonbase_skeleton/features/bases/domain/repositories/base_repository.dart';

class RenameBaseParams {
  const RenameBaseParams({required this.baseId, required this.newName, required this.requesterUserId});

  final BaseId baseId;
  final String newName;
  final UserId requesterUserId;
}

class RenameBase implements UseCase<void, RenameBaseParams> {
  const RenameBase(this.repo);

  final BaseRepository repo;

  @override
  Future<Either<Failure, void>> call(RenameBaseParams p) {
  final name = p.newName.trim();
  if (!isValidBaseName(name)) {
    return Future.value(const Left(ValidationFailure('Base name must be 1–32 characters.')));
  }
  return repo.renameBase(baseId: p.baseId, newName: name, requesterUserId: p.requesterUserId);
}
}
