import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/core/usecase.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/invite.dart';
import 'package:moonbase_skeleton/features/bases/domain/repositories/base_repository.dart';

class CreateInviteParams {
  const CreateInviteParams({
    required this.baseId,
    required this.createdByUserId,
    this.maxUses,
    this.expiresAt,
  });

  final BaseId baseId;
  final UserId createdByUserId;
  final int? maxUses;
  final DateTime? expiresAt;
}

class CreateInvite implements UseCase<Invite, CreateInviteParams> {
  const CreateInvite(this.repo);

  final BaseRepository repo;

  @override
  Future<Either<Failure, Invite>> call(CreateInviteParams p) async {
    // Validate maxUses if provided
    if (p.maxUses != null && p.maxUses! <= 0) {
      return const Left<Failure, Invite>(ValidationFailure('Max uses must be greater than 0'));
    }
    
    // Validate expiration date if provided
    if (p.expiresAt != null && p.expiresAt!.isBefore(DateTime.now())) {
      return const Left<Failure, Invite>(ValidationFailure('Expiration date must be in the future'));
    }
    
    return repo.createInvite(
      baseId: p.baseId,
      createdByUserId: p.createdByUserId,
      maxUses: p.maxUses,
      expiresAt: p.expiresAt,
    );
  }
}
