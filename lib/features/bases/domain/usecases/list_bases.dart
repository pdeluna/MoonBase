import '../../../../core/either.dart';
import '../../../../core/failure.dart';
import '../../../../core/usecase.dart';
import '../entities/base.dart';
import '../repositories/base_repository.dart';

class ListBasesParams {
  final String userId;
  const ListBasesParams(this.userId);
}

class ListBases implements UseCase<List<Base>, ListBasesParams> {
  final BaseRepository repo;
  const ListBases(this.repo);

  @override
  Future<Either<Failure, List<Base>>> call(ListBasesParams p) =>
      repo.listBases(userId: p.userId);
}
