import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/core/usecase.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/invite.dart';
import 'package:moonbase_skeleton/features/bases/domain/repositories/base_repository.dart';

class ListInvitesParams {
  const ListInvitesParams({required this.baseId});

  final BaseId baseId;
}

class ListInvites implements UseCase<List<Invite>, ListInvitesParams> {
  const ListInvites(this.repo);

  final BaseRepository repo;

  @override
  Future<Either<Failure, List<Invite>>> call(ListInvitesParams p) =>
      repo.listInvitesForBase(baseId: p.baseId);
}
