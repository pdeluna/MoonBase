import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/usecase.dart';
import 'package:moonbase_skeleton/features/profile/domain/entities/profile.dart';
import 'package:moonbase_skeleton/features/profile/domain/repositories/profile_repository.dart';

class GetProfileParams {
  const GetProfileParams(this.userId);

  final String userId;
}

class GetProfile implements UseCase<Profile?, GetProfileParams> {
  const GetProfile(this.repo);

  final ProfileRepository repo;

  @override
  Future<Either<Failure, Profile?>> call(GetProfileParams p) =>
      repo.getProfile(p.userId);
}
