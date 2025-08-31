import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonbase_skeleton/models/invite.dart';
import 'package:moonbase_skeleton/models/base_member.dart';
import 'package:moonbase_skeleton/services/invites_repository.dart';
import 'package:moonbase_skeleton/services/session_controller.dart';
import 'package:moonbase_skeleton/providers/bases_provider.dart';

// Repository provider
final invitesRepositoryProvider = Provider<InvitesRepository>((ref) {
  return SpInvitesRepository();
});

// Invites provider - manages invite operations
final invitesProvider = StateNotifierProvider<InvitesNotifier, AsyncValue<void>>((ref) {
  final repository = ref.watch(invitesRepositoryProvider);
  final session = ref.watch(sessionProvider);
  final basesNotifier = ref.read(basesProvider.notifier);
  final selectedBaseNotifier = ref.read(selectedBaseProvider.notifier);
  
  return InvitesNotifier(repository, session, basesNotifier, selectedBaseNotifier);
});

// Invite validation provider - validates invite codes
final inviteValidationProvider = StateNotifierProvider.family<InviteValidationNotifier, AsyncValue<BaseInvite?>, String>((ref, code) {
  final repository = ref.watch(invitesRepositoryProvider);
  return InviteValidationNotifier(repository, code);
});

class InvitesNotifier extends StateNotifier<AsyncValue<void>> {
  InvitesNotifier(
    this._repository,
    this._session,
    this._basesNotifier,
    this._selectedBaseNotifier,
  ) : super(const AsyncValue.data(null));

  final InvitesRepository _repository;
  final AsyncValue<dynamic> _session;
  final BasesNotifier _basesNotifier;
  final SelectedBaseNotifier _selectedBaseNotifier;

  Future<BaseInvite> createInvite({
    required String baseId,
    int? maxUses,
    DateTime? expiresAt,
  }) async {
    if (_session.value == null) {
      throw Exception('User not authenticated');
    }

    try {
      state = const AsyncValue.loading();
      final invite = await _repository.createInvite(
        baseId: baseId,
        userId: _session.value!.userId,
        maxUses: maxUses,
        expiresAt: expiresAt,
      );
      state = const AsyncValue.data(null);
      return invite;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<BaseMember> redeemInvite(String code) async {
    if (_session.value == null) {
      throw Exception('User not authenticated');
    }

    try {
      state = const AsyncValue.loading();
      final member = await _repository.redeemInvite(
        code: code,
        userId: _session.value!.userId,
      );
      
      // Refresh bases list to include the newly joined base
      await _basesNotifier.joinBase(member.baseId);
      
      // Optionally select the newly joined base
      final bases = _basesNotifier.state.value;
      if (bases != null) {
        final joinedBase = bases.firstWhere((base) => base.id == member.baseId);
        _selectedBaseNotifier.selectBase(joinedBase);
      }
      
      state = const AsyncValue.data(null);
      return member;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<BaseInvite?> validateInvite(String code) async {
    try {
      return await _repository.getByCode(code);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }
}

class InviteValidationNotifier extends StateNotifier<AsyncValue<BaseInvite?>> {
  InviteValidationNotifier(this._repository, this._code) : super(const AsyncValue.loading()) {
    _validateInvite();
  }

  final InvitesRepository _repository;
  final String _code;

  Future<void> _validateInvite() async {
    try {
      state = const AsyncValue.loading();
      final invite = await _repository.getByCode(_code);
      
      if (invite == null) {
        state = const AsyncValue.data(null);
        return;
      }

      // Check if invite is valid
      if (invite.isExpired) {
        state = const AsyncValue.data(null);
        return;
      }

      if (invite.isDepleted) {
        state = const AsyncValue.data(null);
        return;
      }

      state = AsyncValue.data(invite);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    await _validateInvite();
  }
}
