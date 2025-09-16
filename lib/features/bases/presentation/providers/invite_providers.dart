import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/invite.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base.dart';
import 'package:moonbase_skeleton/features/bases/domain/usecases/create_invite.dart';
import 'package:moonbase_skeleton/features/bases/domain/usecases/list_invites.dart';
import 'package:moonbase_skeleton/features/bases/domain/usecases/get_invite_by_code.dart';
import 'package:moonbase_skeleton/features/bases/domain/usecases/join_base.dart';
import 'package:moonbase_skeleton/features/bases/presentation/providers/base_providers.dart';
import 'package:moonbase_skeleton/features/auth/presentation/providers/current_user_id_provider.dart';
import 'package:moonbase_skeleton/core/ids.dart';

/// Provider for creating invites
final createInviteProvider = FutureProvider.family<Invite?, CreateInviteParams>((ref, params) async {
  final createInvite = ref.read(createInviteUseCaseProvider);
  final result = await createInvite(params);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (invite) => invite,
  );
});

/// Provider for listing invites for a base
final baseInvitesProvider = FutureProvider.family<List<Invite>, String>((ref, baseId) async {
  final listInvites = ref.read(listInvitesUseCaseProvider);
  final result = await listInvites(ListInvitesParams(baseId: baseId.bid));
  return result.fold(
    (failure) => throw Exception(failure.message),
    (invites) => invites,
  );
});

/// Provider for getting invite by code
final inviteByCodeProvider = FutureProvider.family<Invite?, String>((ref, code) async {
  final getInviteByCode = ref.read(getInviteByCodeUseCaseProvider);
  final result = await getInviteByCode(GetInviteByCodeParams(code: code));
  return result.fold(
    (failure) => throw Exception(failure.message),
    (invite) => invite,
  );
});

/// Provider for joining a base with invite code
final joinBaseWithInviteProvider = FutureProvider.family<Base?, String>((ref, inviteCode) async {
  final currentUserId = ref.read(currentUserIdProvider);
  if (currentUserId == null) {
    throw Exception('User not authenticated');
  }
  
  final joinBase = ref.read(joinBaseUseCaseProvider);
  final result = await joinBase(JoinBaseParams(inviteCode: inviteCode, userId: currentUserId.uid));
  return result.fold(
    (failure) => throw Exception(failure.message),
    (base) => base,
  );
});
