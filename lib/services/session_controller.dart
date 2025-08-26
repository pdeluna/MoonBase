import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:moonbase_skeleton/services/profile_repository.dart';
import 'package:moonbase_skeleton/models/profile.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return SpProfileRepository();
});

final sessionProvider =
    StateNotifierProvider<SessionController, AsyncValue<Profile?>>((ref) {
  return SessionController(ref.read(profileRepositoryProvider))..bootstrap();
});

class SessionController extends StateNotifier<AsyncValue<Profile?>> {
  SessionController(this._repo) : super(const AsyncValue.loading());
  final ProfileRepository _repo;

  Future<void> bootstrap() async {
    try {
      state = const AsyncValue.loading();
      final p = await _repo.read();
      state = AsyncValue.data(p);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signIn(String nickname) async {
    final profile = Profile(
      userId: const Uuid().v4(),
      nickname: nickname.trim(),
      createdAt: DateTime.now().toIso8601String(),
    );
    await _repo.write(profile);
    state = AsyncValue.data(profile);
  }

  Future<void> signOut() async {
    await _repo.clear();
    state = const AsyncValue.data(null);
  }
}
