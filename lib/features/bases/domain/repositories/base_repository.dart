import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base.dart';

abstract class BaseRepository {
  Future<Either<Failure, Base>> createBase({
    required String name,
    required String ownerUserId,
  });

  Future<Either<Failure, Base>> joinBase({
    required String inviteCode,
    required String userId,
  });

  Future<Either<Failure, List<Base>>> listBases({required String userId});

  // Optional for later (UI already hints at these)
  Future<Either<Failure, void>> leaveBase({required String baseId, required String userId});
  Future<Either<Failure, void>> renameBase({required String baseId, required String newName, required String requesterUserId});
  Future<Either<Failure, void>> deleteBase({required String baseId, required String requesterUserId});
  Future<Either<Failure, String>> generateInviteCode({required String baseId, required String requesterUserId});
}
