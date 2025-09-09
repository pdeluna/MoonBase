import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/profile.dart';
import '../providers/profile_providers.dart';
import '../../domain/usecases/get_profile.dart';
import '../../domain/usecases/update_profile.dart';

class ProfileState {
  final AsyncValue<Profile?> current;
  const ProfileState({this.current = const AsyncValue.data(null)});

  ProfileState copyWith({AsyncValue<Profile?>? current}) =>
      ProfileState(current: current ?? this.current);
}

class ProfileController extends StateNotifier<ProfileState> {
  final GetProfile _getProfile;
  final UpdateProfile _updateProfile;

  ProfileController(this._getProfile, this._updateProfile)
      : super(const ProfileState());

  Future<void> load(String userId) async {
    state = state.copyWith(current: const AsyncValue.loading());
    final res = await _getProfile(GetProfileParams(userId));
    state = res.match(
      (f) => state.copyWith(current: AsyncValue.error(f, StackTrace.current)),
      (p)  => state.copyWith(current: AsyncValue.data(p)),
    );
  }

  Future<void> updateNickname(String userId, String nickname) async {
    final res = await _updateProfile(UpdateProfileParams(userId: userId, nickname: nickname));
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
