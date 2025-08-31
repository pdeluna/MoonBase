import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonbase_skeleton/models/base.dart';
import 'package:moonbase_skeleton/models/base_member.dart';
import 'package:moonbase_skeleton/models/enums.dart';
import 'package:moonbase_skeleton/services/bases_repository.dart';
import 'package:moonbase_skeleton/services/session_controller.dart';

// Repository provider
final basesRepositoryProvider = Provider<BasesRepository>((ref) {
  return SpBasesRepository();
});

// Bases provider - manages list of user's bases
final basesProvider = StateNotifierProvider<BasesNotifier, AsyncValue<List<Base>>>((ref) {
  final repository = ref.watch(basesRepositoryProvider);
  final session = ref.watch(sessionProvider);
  
  return BasesNotifier(repository, session);
});

// Selected base provider - manages currently selected base
final selectedBaseProvider = StateNotifierProvider<SelectedBaseNotifier, Base?>((ref) {
  return SelectedBaseNotifier();
});

// Base members provider - manages members of a specific base
final baseMembersProvider = StateNotifierProvider.family<BaseMembersNotifier, AsyncValue<List<BaseMember>>, String>((ref, baseId) {
  final repository = ref.watch(basesRepositoryProvider);
  return BaseMembersNotifier(repository, baseId);
});

class BasesNotifier extends StateNotifier<AsyncValue<List<Base>>> {
  BasesNotifier(this._repository, this._session) : super(const AsyncValue.loading()) {
    _loadBases();
  }

  final BasesRepository _repository;
  final AsyncValue<dynamic> _session;

  Future<void> _loadBases() async {
    if (_session.value == null) {
      state = const AsyncValue.data([]);
      return;
    }

    try {
      state = const AsyncValue.loading();
      final userId = _session.value!.userId;
      final bases = await _repository.listMyBases(userId);
      state = AsyncValue.data(bases);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createBase({
    required String name,
    String? description,
    String? avatarUrl,
  }) async {
    if (_session.value == null) return;

    try {
      final newBase = await _repository.createBase(
        name: name,
        description: description,
        avatarUrl: avatarUrl,
      );

      // Add the new base to the list
      final currentBases = state.value ?? [];
      state = AsyncValue.data([newBase, ...currentBases]);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> joinBase(String baseId) async {
    // This will be called when user joins via invite code
    // The base should already be added to their list by the invite redemption
    await _loadBases();
  }

  Future<void> deleteBase(String baseId) async {
    try {
      await _repository.deleteBase(baseId);
      
      // Remove from list
      final currentBases = state.value ?? [];
      final updatedBases = currentBases.where((base) => base.id != baseId).toList();
      state = AsyncValue.data(updatedBases);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    await _loadBases();
  }
}

class SelectedBaseNotifier extends StateNotifier<Base?> {
  SelectedBaseNotifier() : super(null);

  void selectBase(Base base) {
    state = base;
  }

  void clearSelection() {
    state = null;
  }

  bool get hasSelectedBase => state != null;
}

class BaseMembersNotifier extends StateNotifier<AsyncValue<List<BaseMember>>> {
  BaseMembersNotifier(this._repository, this._baseId) : super(const AsyncValue.loading()) {
    _loadMembers();
  }

  final BasesRepository _repository;
  final String _baseId;

  Future<void> _loadMembers() async {
    try {
      state = const AsyncValue.loading();
      final members = await _repository.listMembers(_baseId);
      state = AsyncValue.data(members);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addMember({
    required String userId,
    required BaseRole role,
  }) async {
    try {
      await _repository.addMember(
        baseId: _baseId,
        userId: userId,
        role: role,
      );
      await _loadMembers(); // Refresh the list
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> removeMember(String userId) async {
    try {
      await _repository.removeMember(
        baseId: _baseId,
        userId: userId,
      );
      await _loadMembers(); // Refresh the list
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    await _loadMembers();
  }
}
