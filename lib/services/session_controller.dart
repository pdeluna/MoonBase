import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:moonbase_skeleton/services/profile_repository.dart';
import 'package:moonbase_skeleton/models/profile.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return SpProfileRepository();
});

// Development flag to help with caching issues
const _developmentMode = true; // TODO: set to false for production

final sessionProvider =
    StateNotifierProvider<SessionController, AsyncValue<Profile?>>((ref) {
  debugPrint('SessionProvider: Creating new SessionController (dev mode: $_developmentMode)');
  return SessionController(ref.read(profileRepositoryProvider))..bootstrap();
});

// Provider to get profiles by user ID
final profileByUserIdProvider = FutureProvider.family<Profile?, String>((ref, userId) async {
  final repository = ref.read(profileRepositoryProvider);
  return repository.getProfileByUserId(userId);
});

class SessionController extends StateNotifier<AsyncValue<Profile?>> {
  SessionController(this._repo) : super(const AsyncValue.loading()) {
    debugPrint('SessionController: Constructor called');
  }
  final ProfileRepository _repo;

  Future<void> bootstrap() async {
    debugPrint('SessionController: bootstrap() called');
    try {
      state = const AsyncValue.loading();
      debugPrint('SessionController: Set state to loading');
      
      // Add a small delay in development mode to ensure splash screen is visible
      if (_developmentMode) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      final p = await _repo.read();
      debugPrint('SessionController: Profile read result: $p');
      state = AsyncValue.data(p);
      debugPrint('SessionController: Set state to data');
    } catch (e, st) {
      debugPrint('SessionController: Error during bootstrap: $e');
      state = AsyncValue.error(e, st);
    }
  }

Future<void> signIn(String nickname) async {
  try {
    final repo = _repo as SpProfileRepository; // safe in Phase 1
    final p = await repo.signInByNickname(nickname);
    state = AsyncValue.data(p);
  } catch (e, st) {
    state = AsyncValue.error(e, st);
  }
}

  Future<void> updateTheme(String mode) async { // "light" | "dark"
    final current = state.value;
    if (current == null) return;
    final updated = Profile(
      userId: current.userId,
      nickname: current.nickname,
      createdAt: current.createdAt,
      themeMode: mode,
    );
    await _repo.write(updated);
    state = AsyncValue.data(updated);
  }

  Future<void> signOut() async {
    await _repo.clear();
    state = const AsyncValue.data(null);
  }
}
