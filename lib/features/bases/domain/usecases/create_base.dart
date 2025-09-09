import '../../../../core/either.dart';
import '../../../../core/failure.dart';
import '../../../../core/usecase.dart';
import '../entities/base.dart';
import '../repositories/base_repository.dart';

class CreateBaseParams {
  final String name;
  final String ownerUserId;
  const CreateBaseParams({required this.name, required this.ownerUserId});
}

class CreateBase implements UseCase<Base, CreateBaseParams> {
  final BaseRepository repo;
  const CreateBase(this.repo);

  @override
  Future<Either<Failure, Base>> call(CreateBaseParams p) =>
      repo.createBase(name: p.name, ownerUserId: p.ownerUserId);
}
