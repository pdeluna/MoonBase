import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base_member.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/invite.dart';

abstract class BaseRepository {
  Future<Either<Failure, Base>> createBase({
    required String name,
    required UserId ownerUserId,
  });

  Future<Either<Failure, Base>> joinBase({
    required String inviteCode,
    required UserId userId,
  });

  Future<Either<Failure, List<Base>>> listBases({required UserId userId});

  Future<Either<Failure, List<BaseMember>>> listMembersForBase({
    required BaseId baseId,
  });

  // Optional for later (UI already hints at these)
  Future<Either<Failure, void>> leaveBase({required BaseId baseId, required UserId userId});
  Future<Either<Failure, void>> renameBase({required BaseId baseId, required String newName, required UserId requesterUserId});
  Future<Either<Failure, void>> deleteBase({required BaseId baseId, required UserId requesterUserId});
  Future<Either<Failure, String>> generateInviteCode({required BaseId baseId, required UserId requesterUserId});

  // Invite management
  Future<Either<Failure, Invite>> createInvite({
    required BaseId baseId,
    required UserId createdByUserId,
    int? maxUses,
    DateTime? expiresAt,
  });
  Future<Either<Failure, List<Invite>>> listInvitesForBase({required BaseId baseId});
  Future<Either<Failure, Invite?>> getInviteByCode({required String code});
  
  // Last accessed base methods (per user)
  Future<Either<Failure, Base?>> getLastAccessedBase(UserId userId);
  Future<Either<Failure, void>> setLastAccessedBase({required UserId userId, required BaseId baseId});
}
