import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/core/usecase.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base.dart';
import 'package:moonbase_skeleton/features/bases/domain/repositories/base_repository.dart';
import 'package:moonbase_skeleton/core/validators.dart';

class JoinBaseParams {
  const JoinBaseParams({required this.inviteCode, required this.userId});

  final String inviteCode;
  final UserId userId;
}

class JoinBase implements UseCase<Base, JoinBaseParams> {
  const JoinBase(this.repo);

  final BaseRepository repo;

@override
Future<Either<Failure, Base>> call(JoinBaseParams p) {
  final code = normalizeInviteCode(p.inviteCode);
  if (!isValidInviteCode(code)) {
    return Future.value(const Left(ValidationFailure('Invalid invite code (6 chars, A–Z & 2–9).')));
  }
  return repo.joinBase(inviteCode: code, userId: p.userId);
}
}
