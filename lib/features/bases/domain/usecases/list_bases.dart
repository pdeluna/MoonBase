import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/usecase.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base.dart';
import 'package:moonbase_skeleton/features/bases/domain/repositories/base_repository.dart';

class ListBasesParams {
  const ListBasesParams(this.userId);

  final String userId;
}

class ListBases implements UseCase<List<Base>, ListBasesParams> {
  const ListBases(this.repo);

  final BaseRepository repo;

  @override
  Future<Either<Failure, List<Base>>> call(ListBasesParams p) =>
      repo.listBases(userId: p.userId);
}
