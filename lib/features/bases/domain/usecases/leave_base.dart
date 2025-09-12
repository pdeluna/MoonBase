import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/usecase.dart';
import 'package:moonbase_skeleton/features/bases/domain/repositories/base_repository.dart';

class LeaveBaseParams {
  const LeaveBaseParams({required this.baseId, required this.userId});

  final String baseId;
  final String userId;
}

class LeaveBase implements UseCase<void, LeaveBaseParams> {
  const LeaveBase(this.repo);

  final BaseRepository repo;

  @override
  Future<Either<Failure, void>> call(LeaveBaseParams p) =>
      repo.leaveBase(baseId: p.baseId, userId: p.userId);
}
