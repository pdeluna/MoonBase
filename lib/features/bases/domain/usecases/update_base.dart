import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/core/usecase.dart';
import 'package:moonbase_skeleton/core/validators.dart';
import 'package:moonbase_skeleton/features/bases/domain/repositories/base_repository.dart';

class UpdateBaseParams {
  const UpdateBaseParams({
    required this.baseId,
    required this.name,
    required this.requesterUserId,
  });

  final BaseId baseId;
  final String name;
  final UserId requesterUserId;
}

class UpdateBase implements UseCase<void, UpdateBaseParams> {
  const UpdateBase(this.repo);

  final BaseRepository repo;

  @override
  Future<Either<Failure, void>> call(UpdateBaseParams p) async {
    final name = p.name.trim();
    if (!isValidBaseName(name)) {
      return const Left(ValidationFailure('Base name must be 1–32 characters.'));
    }
    
    return repo.renameBase(
      baseId: p.baseId,
      newName: name,
      requesterUserId: p.requesterUserId,
    );
  }
}
