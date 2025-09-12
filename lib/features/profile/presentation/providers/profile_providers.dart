import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:moonbase_skeleton/features/profile/domain/repositories/profile_repository.dart';
import 'package:moonbase_skeleton/features/profile/domain/usecases/get_profile.dart';
import 'package:moonbase_skeleton/features/profile/domain/usecases/update_profile.dart';

/// Override this at app root with your concrete repo.
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  throw UnimplementedError('Provide ProfileRepository in app wiring');
});

final getProfileUseCaseProvider   = Provider((ref) => GetProfile(ref.read(profileRepositoryProvider)));
final updateProfileUseCaseProvider = Provider((ref) => UpdateProfile(ref.read(profileRepositoryProvider)));
