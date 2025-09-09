import '../../../../core/either.dart';
import '../../../../core/failure.dart';
import '../../domain/entities/base.dart';
import '../../domain/repositories/base_repository.dart';
import '../datasources/base_local_data_source.dart';
import '../datasources/base_remote_data_source.dart';
import '../models/base_model.dart';

class BaseRepositoryImpl implements BaseRepository {
  final BaseLocalDataSource local;
  final BaseRemoteDataSource? remote;

  BaseRepositoryImpl({required this.local, this.remote});

  @override
  Future<Either<Failure, Base>> createBase({
    required String name,
    required String ownerUserId,
  }) async {
    try {
      final BaseModel m = await local.createBase(name: name, ownerUserId: ownerUserId);
      return Right(m.toEntity());
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Base>> joinBase({
    required String inviteCode,
    required String userId,
  }) async {
    try {
      final BaseModel m = await local.joinBase(inviteCode: inviteCode, userId: userId);
      return Right(m.toEntity());
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Base>>> listBases({required String userId}) async {
    try {
      final models = await local.listBasesForUser(userId);
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> renameBase({
    required String baseId,
    required String newName,
    required String requesterUserId,
  }) async {
    try {
      // (AuthZ left for remote impl; local keeps it simple)
      await local.renameBase(baseId: baseId, newName: newName);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteBase({
    required String baseId,
    required String requesterUserId,
  }) async {
    try {
      await local.deleteBase(baseId: baseId);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> generateInviteCode({
    required String baseId,
    required String requesterUserId,
  }) async {
    try {
      final code = await local.generateInviteCode(baseId: baseId);
      return Right(code);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }
}
