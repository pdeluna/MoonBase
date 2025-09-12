import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:moonbase_skeleton/features/profile/domain/entities/profile.dart';
import 'package:moonbase_skeleton/features/profile/presentation/providers/profile_providers.dart';
import 'package:moonbase_skeleton/features/profile/domain/usecases/get_profile.dart';
import 'package:moonbase_skeleton/features/profile/domain/usecases/update_profile.dart';
import 'package:moonbase_skeleton/core/ids.dart';

class ProfileState {
  const ProfileState({this.current = const AsyncValue.data(null)});

  final AsyncValue<Profile?> current;

  ProfileState copyWith({AsyncValue<Profile?>? current}) =>
      ProfileState(current: current ?? this.current);
}

class ProfileController extends StateNotifier<ProfileState> {
  ProfileController(this._getProfile, this._updateProfile)
      : super(const ProfileState());

  final GetProfile _getProfile;
  final UpdateProfile _updateProfile;

  Future<void> load(String userId) async {
    state = state.copyWith(current: const AsyncValue.loading());
    final res = await _getProfile(GetProfileParams(userId.uid));
    state = res.match(
      (f) => state.copyWith(current: AsyncValue.error(f, StackTrace.current)),
      (p)  => state.copyWith(current: AsyncValue.data(p)),
    );
  }

  Future<void> updateNickname(String userId, String nickname) async {
    final res = await _updateProfile(UpdateProfileParams(userId: userId.uid, nickname: nickname));
    state = res.match(
      (f) => state.copyWith(current: AsyncValue.error(f, StackTrace.current)),
      (p)  => state.copyWith(current: AsyncValue.data(p)),
    );
  }
}

final profileControllerProvider = StateNotifierProvider<ProfileController, ProfileState>((ref) {
  return ProfileController(
    ref.read(getProfileUseCaseProvider),
    ref.read(updateProfileUseCaseProvider),
  );
});
