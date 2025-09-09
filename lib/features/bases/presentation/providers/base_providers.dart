import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/repositories/base_repository.dart';
import '../../domain/usecases/create_base.dart';
import '../../domain/usecases/join_base.dart';
import '../../domain/usecases/list_bases.dart';

/// Wire this in app DI by overriding with your concrete impl.
final baseRepositoryProvider = Provider<BaseRepository>((ref) {
  throw UnimplementedError('Provide BaseRepository in app wiring');
});

final createBaseUseCaseProvider = Provider((ref) => CreateBase(ref.read(baseRepositoryProvider)));
final joinBaseUseCaseProvider   = Provider((ref) => JoinBase(ref.read(baseRepositoryProvider)));
final listBasesUseCaseProvider  = Provider((ref) => ListBases(ref.read(baseRepositoryProvider)));
