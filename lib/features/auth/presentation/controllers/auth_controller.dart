import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:moonbase_skeleton/core/usecase.dart';
import 'package:moonbase_skeleton/features/auth/domain/entities/user.dart';
import 'package:moonbase_skeleton/features/auth/domain/usecases/get_current_user.dart';
import 'package:moonbase_skeleton/features/auth/domain/usecases/sign_in.dart';
import 'package:moonbase_skeleton/features/auth/domain/usecases/sign_out.dart';
import 'package:moonbase_skeleton/features/auth/domain/usecases/sign_up.dart';
import 'package:moonbase_skeleton/features/auth/presentation/providers/auth_providers.dart';

class AuthState {
  const AuthState({this.current = const AsyncValue.loading()});

  final AsyncValue<User?> current;

  AuthState copyWith({AsyncValue<User?>? current}) =>
      AuthState(current: current ?? this.current);
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._getCurrent, this._signUp, this._signIn, this._signOut)
      : super(const AuthState());

  final GetCurrentUser _getCurrent;
  final SignUp _signUp;
  final SignIn _signIn;
  final SignOut _signOut;

  Future<void> load() async {
    state = state.copyWith(current: const AsyncValue.loading());
    final res = await _getCurrent(const NoParams());
    state = res.match(
      (f) => state.copyWith(current: AsyncValue.error(f, StackTrace.current)),
      (u) => state.copyWith(current: AsyncValue.data(u)),
    );
  }

  Future<void> signUp(String email, String password, {required String nickname}) async {
    state = state.copyWith(current: const AsyncValue.loading());
    final res = await _signUp(SignUpParams(
      email: email,
      password: password,
      nickname: nickname,
    ));
    state = res.match(
      (f) => state.copyWith(current: AsyncValue.error(f, StackTrace.current)),
      (u) => state.copyWith(current: AsyncValue.data(u)),
    );
  }

  Future<void> signIn(String email, String password) async {
    state = state.copyWith(current: const AsyncValue.loading());
    final res = await _signIn(SignInParams(email: email, password: password));
    state = res.match(
      (f) => state.copyWith(current: AsyncValue.error(f, StackTrace.current)),
      (u) => state.copyWith(current: AsyncValue.data(u)),
    );
  }

  Future<void> signOut() async {
    final res = await _signOut(const NoParams());
    state = res.match(
      (f) => state.copyWith(current: AsyncValue.error(f, StackTrace.current)),
      (_) => state.copyWith(current: const AsyncValue.data(null)),
    );
  }

  /// Alias for signOut to match expected API
  Future<void> logout() async => signOut();

  /// Placeholder for updateProfile - TODO: implement when profile system is integrated
  Future<void> updateProfile(dynamic profile) async {
    // TODO: Implement profile update when profile system is integrated
    // For now, just reload the current user
    await load();
  }
}

/// Controller provider (compose it where you need it)
final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(
    ref.read(getCurrentUserProvider),
    ref.read(signUpUseCaseProvider),
    ref.read(signInUseCaseProvider),
    ref.read(signOutUseCaseProvider),
  )..load();
});
