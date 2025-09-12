import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
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
Future<Either<Failure, Base>> createBase({required String name, required UserId ownerUserId}) =>
  guard(() async {
    final m = await local.createBase(name: name, ownerUserId: ownerUserId.value);
    return m.toEntity();
  });

@override
Future<Either<Failure, Base>> joinBase({required String inviteCode, required UserId userId}) =>
  guard(() async {
    final m = await local.joinBase(inviteCode: inviteCode, userId: userId.value);
    return m.toEntity();
  });

@override
Future<Either<Failure, List<Base>>> listBases({required UserId userId}) =>
  guard(() async {
    final ms = await local.listBasesForUser(userId.value);
    return ms.map((m) => m.toEntity()).toList();
  });

@override
Future<Either<Failure, void>> leaveBase({required BaseId baseId, required UserId userId}) =>
  guardVoid(() => local.leaveBase(baseId: baseId.value, userId: userId.value));

@override
Future<Either<Failure, void>> renameBase({required BaseId baseId, required String newName, required UserId requesterUserId}) =>
  guardVoid(() => local.renameBase(baseId: baseId.value, newName: newName));

@override
Future<Either<Failure, void>> deleteBase({required BaseId baseId, required UserId requesterUserId}) =>
  guardVoid(() => local.deleteBase(baseId: baseId.value));

@override
Future<Either<Failure, String>> generateInviteCode({required BaseId baseId, required UserId requesterUserId}) =>
  guard(() => local.generateInviteCode(baseId: baseId.value));
}
