import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:moonbase_skeleton/services/profile_repository.dart';
import 'package:moonbase_skeleton/models/profile.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return SpProfileRepository();
});

// Development flag to help with caching issues
final _developmentMode = true;

final sessionProvider =
    StateNotifierProvider<SessionController, AsyncValue<Profile?>>((ref) {
  debugPrint('SessionProvider: Creating new SessionController (dev mode: $_developmentMode)');
  return SessionController(ref.read(profileRepositoryProvider))..bootstrap();
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
