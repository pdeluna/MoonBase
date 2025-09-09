import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/usecase.dart';
import '../../domain/entities/user.dart';
import '../../domain/usecases/get_current_user.dart';
import '../../domain/usecases/sign_in.dart';
import '../../domain/usecases/sign_out.dart';
import '../providers/auth_providers.dart';

class AuthState {
  final AsyncValue<User?> current;
  const AuthState({this.current = const AsyncValue.loading()});

  AuthState copyWith({AsyncValue<User?>? current}) =>
      AuthState(current: current ?? this.current);
}

class AuthController extends StateNotifier<AuthState> {
  final GetCurrentUser _getCurrent;
  final SignIn _signIn;
  final SignOut _signOut;

  AuthController(this._getCurrent, this._signIn, this._signOut)
      : super(const AuthState());

  Future<void> load() async {
    state = state.copyWith(current: const AsyncValue.loading());
    final res = await _getCurrent(const NoParams());
    state = res.match(
      (f) => state.copyWith(current: AsyncValue.error(f, StackTrace.current)),
      (u) => state.copyWith(current: AsyncValue.data(u)),
    );
  }

  Future<void> signIn(String nickname) async {
    state = state.copyWith(current: const AsyncValue.loading());
    final res = await _signIn(SignInParams(nickname));
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
}

/// Controller provider (compose it where you need it)
final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(
    ref.read(getCurrentUserProvider),
    ref.read(signInUseCaseProvider),
    ref.read(signOutUseCaseProvider),
  )..load();
});
