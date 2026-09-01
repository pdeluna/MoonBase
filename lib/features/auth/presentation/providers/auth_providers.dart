import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:moonbase_skeleton/features/auth/domain/repositories/auth_repository.dart';
import 'package:moonbase_skeleton/features/auth/domain/entities/user.dart';
import 'package:moonbase_skeleton/features/auth/domain/usecases/get_current_user.dart';
import 'package:moonbase_skeleton/features/auth/domain/usecases/sign_in.dart';
import 'package:moonbase_skeleton/features/auth/domain/usecases/sign_out.dart';
import 'package:moonbase_skeleton/features/auth/domain/usecases/sign_up.dart';
import 'package:moonbase_skeleton/features/auth/presentation/controllers/auth_controller.dart';

/// Repository token. Wire this in your app DI (e.g., main.dart) by overriding it:
/// ProviderScope(overrides: [authRepositoryProvider.overrideWithValue(AuthRepositoryImpl(...))])
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  throw UnimplementedError('Provide AuthRepository in app wiring');
});

final signUpUseCaseProvider =
    Provider((ref) => SignUp(ref.read(authRepositoryProvider)));
final signInUseCaseProvider =
    Provider((ref) => SignIn(ref.read(authRepositoryProvider)));
final signOutUseCaseProvider =
    Provider((ref) => SignOut(ref.read(authRepositoryProvider)));
final getCurrentUserProvider =
    Provider((ref) => GetCurrentUser(ref.read(authRepositoryProvider)));

/// Session for the gate: pass-through of [AuthController.current].
///
/// Does not flatten loading or error to `null`. Only [AsyncValue.data] with a
/// null user is signed out. Consumers that need a [User]? (chrome, ids) use
/// [AsyncValue.valueOrNull].
final currentUserProvider = Provider<AsyncValue<User?>>((ref) {
  return ref.watch(authControllerProvider).current;
});
