import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:moonbase_skeleton/features/bases/domain/repositories/base_repository.dart';
import 'package:moonbase_skeleton/features/bases/domain/usecases/create_base.dart';
import 'package:moonbase_skeleton/features/bases/domain/usecases/join_base.dart';
import 'package:moonbase_skeleton/features/bases/domain/usecases/list_bases.dart';
import 'package:moonbase_skeleton/features/bases/domain/usecases/leave_base.dart';
import 'package:moonbase_skeleton/features/bases/domain/usecases/rename_base.dart';
import 'package:moonbase_skeleton/features/bases/domain/usecases/delete_base.dart';
import 'package:moonbase_skeleton/features/bases/domain/usecases/update_base.dart';
import 'package:moonbase_skeleton/features/bases/domain/usecases/generate_invite_code.dart';
import 'package:moonbase_skeleton/features/bases/domain/usecases/create_invite.dart';
import 'package:moonbase_skeleton/features/bases/domain/usecases/list_invites.dart';
import 'package:moonbase_skeleton/features/bases/domain/usecases/get_invite_by_code.dart';

/// Wire this in app DI by overriding with your concrete impl.
final baseRepositoryProvider = Provider<BaseRepository>((ref) {
  throw UnimplementedError('Provide BaseRepository in app wiring');
});

final createBaseUseCaseProvider = Provider((ref) => CreateBase(ref.read(baseRepositoryProvider)));
final joinBaseUseCaseProvider   = Provider((ref) => JoinBase(ref.read(baseRepositoryProvider)));
final listBasesUseCaseProvider  = Provider((ref) => ListBases(ref.read(baseRepositoryProvider)));
final leaveBaseUseCaseProvider  = Provider((ref) => LeaveBase(ref.read(baseRepositoryProvider)));
final renameBaseUseCaseProvider = Provider((ref) => RenameBase(ref.read(baseRepositoryProvider)));
final updateBaseUseCaseProvider = Provider((ref) => UpdateBase(ref.read(baseRepositoryProvider)));
final deleteBaseUseCaseProvider = Provider((ref) => DeleteBase(ref.read(baseRepositoryProvider)));
final generateInviteCodeUseCaseProvider = Provider((ref) => GenerateInviteCode(ref.read(baseRepositoryProvider)));

// Invite use cases
final createInviteUseCaseProvider = Provider((ref) => CreateInvite(ref.read(baseRepositoryProvider)));
final listInvitesUseCaseProvider = Provider((ref) => ListInvites(ref.read(baseRepositoryProvider)));
final getInviteByCodeUseCaseProvider = Provider((ref) => GetInviteByCode(ref.read(baseRepositoryProvider)));