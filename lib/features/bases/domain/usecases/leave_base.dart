import '../../../../core/either.dart';
import '../../../../core/failure.dart';
import '../../../../core/usecase.dart';
import '../repositories/base_repository.dart';

class LeaveBaseParams {
  final String baseId;
  final String userId;
  const LeaveBaseParams({required this.baseId, required this.userId});
}

class LeaveBase implements UseCase<void, LeaveBaseParams> {
  final BaseRepository repo;
  const LeaveBase(this.repo);

  @override
  Future<Either<Failure, void>> call(LeaveBaseParams p) =>
      repo.leaveBase(baseId: p.baseId, userId: p.userId);
}
