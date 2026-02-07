import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:moonbase_skeleton/features/profile/domain/repositories/profile_repository.dart';
import 'package:moonbase_skeleton/features/profile/domain/entities/profile.dart';
import 'package:moonbase_skeleton/features/profile/domain/usecases/get_profile.dart';
import 'package:moonbase_skeleton/features/profile/domain/usecases/update_profile.dart';
import 'package:moonbase_skeleton/core/ids.dart';

/// Override this at app root with your concrete repo.
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  throw UnimplementedError('Provide ProfileRepository in app wiring');
});

final getProfileUseCaseProvider   = Provider((ref) => GetProfile(ref.read(profileRepositoryProvider)));
final updateProfileUseCaseProvider = Provider((ref) => UpdateProfile(ref.read(profileRepositoryProvider)));

/// Provider for getting a profile by user ID
final profileProvider = FutureProvider.family<Profile?, UserId>((ref, userId) async {
  final useCase = ref.read(getProfileUseCaseProvider);
  final result = await useCase(GetProfileParams(userId));
  return result.fold(
    (failure) => null, // Return null on failure, could log error here
    (profile) => profile,
  );
});
