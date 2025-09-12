import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/core/usecase.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base.dart';
import 'package:moonbase_skeleton/features/bases/domain/repositories/base_repository.dart';

class CreateBaseParams {
  const CreateBaseParams({required this.name, required this.ownerUserId});

  final String name;
  final UserId ownerUserId;
}

class CreateBase implements UseCase<Base, CreateBaseParams> {
  const CreateBase(this.repo);

  final BaseRepository repo;

  @override
  Future<Either<Failure, Base>> call(CreateBaseParams p) =>
      repo.createBase(name: p.name, ownerUserId: p.ownerUserId);
}
