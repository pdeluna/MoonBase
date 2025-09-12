import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base.dart';
import 'package:moonbase_skeleton/features/bases/domain/repositories/base_repository.dart';
import 'package:moonbase_skeleton/features/bases/data/datasources/base_local_data_source.dart';
import 'package:moonbase_skeleton/features/bases/data/datasources/base_remote_data_source.dart';
import 'package:moonbase_skeleton/core/error_mapper.dart';

class BaseRepositoryImpl implements BaseRepository {
  BaseRepositoryImpl({required this.local, this.remote});

  final BaseLocalDataSource local;
  final BaseRemoteDataSource? remote;

@override
Future<Either<Failure, Base>> createBase({required String name, required String ownerUserId}) =>
  guard(() async {
    final m = await local.createBase(name: name, ownerUserId: ownerUserId);
    return m.toEntity();
  });

@override
Future<Either<Failure, Base>> joinBase({required String inviteCode, required String userId}) =>
  guard(() async {
    final m = await local.joinBase(inviteCode: inviteCode, userId: userId);
    return m.toEntity();
  });

@override
Future<Either<Failure, List<Base>>> listBases({required String userId}) =>
  guard(() async {
    final ms = await local.listBasesForUser(userId);
    return ms.map((m) => m.toEntity()).toList();
  });

@override
Future<Either<Failure, void>> leaveBase({required String baseId, required String userId}) =>
  guardVoid(() => local.leaveBase(baseId: baseId, userId: userId));

@override
Future<Either<Failure, void>> renameBase({required String baseId, required String newName, required String requesterUserId}) =>
  guardVoid(() => local.renameBase(baseId: baseId, newName: newName));

@override
Future<Either<Failure, void>> deleteBase({required String baseId, required String requesterUserId}) =>
  guardVoid(() => local.deleteBase(baseId: baseId));

@override
Future<Either<Failure, String>> generateInviteCode({required String baseId, required String requesterUserId}) =>
  guard(() => local.generateInviteCode(baseId: baseId));
}
