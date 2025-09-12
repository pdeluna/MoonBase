import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/profile/domain/entities/profile.dart';
import 'package:moonbase_skeleton/features/profile/domain/repositories/profile_repository.dart';
import 'package:moonbase_skeleton/features/profile/data/datasources/profile_local_data_source.dart';
import 'package:moonbase_skeleton/features/profile/data/datasources/profile_remote_data_source.dart';
import 'package:moonbase_skeleton/features/profile/data/models/profile_model.dart';
import 'package:moonbase_skeleton/core/error_mapper.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl({required this.local, this.remote});

  final ProfileLocalDataSource local;
  final ProfileRemoteDataSource? remote;

@override
Future<Either<Failure, Profile?>> getProfile(UserId userId) =>
  guard(() async => (await local.readProfile(userId.value))?.toEntity());

@override
Future<Either<Failure, Profile>> updateProfile({
  required UserId userId,
  String? nickname,
  String? avatarUrl,
}) =>
  guard(() async {
    final existing = await local.readProfile(userId.value);

    final nowUtc = DateTime.now().toUtc();
    final trimmedNick = nickname?.trim();
    final trimmedAvatar = avatarUrl?.trim();

    final next = (existing ??
        ProfileModel(
          userId: userId.value,
          nickname: trimmedNick ?? '',
          avatarUrl: trimmedAvatar,
          updatedAt: nowUtc,
        )
      ).copyWith(
        nickname: trimmedNick ?? existing?.nickname,
        avatarUrl: trimmedAvatar ?? existing?.avatarUrl,
        updatedAt: nowUtc,
      );

    final saved = await local.writeProfile(next);
    return saved.toEntity();
  });
}
