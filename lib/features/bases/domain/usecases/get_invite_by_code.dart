import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/usecase.dart';
import 'package:moonbase_skeleton/core/validators.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/invite.dart';
import 'package:moonbase_skeleton/features/bases/domain/repositories/base_repository.dart';

class GetInviteByCodeParams {
  const GetInviteByCodeParams({required this.code});

  final String code;
}

class GetInviteByCode implements UseCase<Invite?, GetInviteByCodeParams> {
  const GetInviteByCode(this.repo);

  final BaseRepository repo;

  @override
  Future<Either<Failure, Invite?>> call(GetInviteByCodeParams p) async {
    final code = normalizeInviteCode(p.code);
    if (!isValidInviteCode(code)) {
      return const Left<Failure, Invite?>(
        ValidationFailure('Invalid invite code (6 chars, A–Z & 2–9).'),
      );
    }
    return repo.getInviteByCode(code: code);
  }
}
