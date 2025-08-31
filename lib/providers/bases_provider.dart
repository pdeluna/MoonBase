import 'dart:developer' as developer;
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

// Computed provider that automatically selects the most recent base
final mostRecentBaseProvider = Provider<Base?>((ref) {
  final bases = ref.watch(basesProvider);
  
  if (bases.isLoading || bases.hasError) return null;
  
  final basesList = bases.value;
  if (basesList == null || basesList.isEmpty) return null;
  
  // Find the most recently accessed base (highest lastAccessedAt timestamp)
  // If lastAccessedAt is null, fall back to createdAt
  return basesList.reduce((a, b) {
    final aTime = a.lastAccessedAt ?? a.createdAt;
    final bTime = b.lastAccessedAt ?? b.createdAt;
    return aTime.isAfter(bTime) ? a : b;
  });
});

// Computed provider that returns the selected base or falls back to the most recent base
final effectiveSelectedBaseProvider = Provider<Base?>((ref) {
  final selectedBase = ref.watch(selectedBaseProvider);
  final mostRecentBase = ref.watch(mostRecentBaseProvider);
  
  // Return the manually selected base if available, otherwise return the most recent base
  return selectedBase ?? mostRecentBase;
});

// Selected base provider - manages currently selected base
// This will automatically reset when the user changes because it depends on the session
final selectedBaseProvider = StateNotifierProvider<SelectedBaseNotifier, Base?>((ref) {
  // Watch the session to ensure this provider resets when user changes
  ref.watch(sessionProvider);
  return SelectedBaseNotifier(ref);
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
  
  // Track the previous session to detect changes
  String? _previousUserId;

  Future<void> _loadBases() async {
    if (_session.value == null) {
      state = const AsyncValue.data([]);
      _previousUserId = null;
      return;
    }

    try {
      final userId = _session.value!.userId;
      
      // Check if user has changed
      if (_previousUserId != null && _previousUserId != userId) {
        // User has changed, clear the selected base
        // We can't directly access the selectedBaseProvider here, 
        // but the sessionWatcherProvider will handle this
      }
      
      _previousUserId = userId;
      state = const AsyncValue.loading();
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
        userId: _session.value!.userId, // Pass the user ID explicitly
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
    if (_session.value == null) return;
    
    try {
      await _repository.deleteBase(baseId, userId: _session.value!.userId);
      
      // Remove from list
      final currentBases = state.value ?? [];
      final updatedBases = currentBases.where((base) => base.id != baseId).toList();
      state = AsyncValue.data(updatedBases);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateBase(String baseId, {
    required String name,
    String? description,
    String? avatarUrl,
  }) async {
    if (_session.value == null) return;
    
    try {
      final updatedBase = await _repository.updateBase(
        baseId,
        name: name,
        description: description,
        avatarUrl: avatarUrl,
        userId: _session.value!.userId,
      );
      
      // Update the base in our local state
      final currentBases = state.value ?? [];
      final updatedBases = currentBases.map((base) {
        if (base.id == baseId) {
          return updatedBase;
        }
        return base;
      }).toList();
      
      state = AsyncValue.data(updatedBases);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    await _loadBases();
  }

  Future<void> updateLastAccessed(String baseId) async {
    try {
      await _repository.updateLastAccessed(baseId);
      
      // Update the base in our local state
      final currentBases = state.value ?? [];
      final updatedBases = currentBases.map((base) {
        if (base.id == baseId) {
          return base.copyWith(lastAccessedAt: DateTime.now());
        }
        return base;
      }).toList();
      
      state = AsyncValue.data(updatedBases);
    } catch (e) {
      // Don't update state on error, just log it
      developer.log('Failed to update last accessed time for base $baseId: $e');
    }
  }
}

class SelectedBaseNotifier extends StateNotifier<Base?> {
  SelectedBaseNotifier(this._ref) : super(null);

  final Ref _ref;

  void selectBase(Base base) {
    state = base;
    // Update the last accessed timestamp for this base
    _ref.read(basesProvider.notifier).updateLastAccessed(base.id);
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
