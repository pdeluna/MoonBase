import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base.dart';
import 'package:moonbase_skeleton/features/bases/presentation/viewmodels/sidebar_vm.dart';
import 'package:moonbase_skeleton/features/bases/presentation/viewmodels/base_tile_vm.dart';
import 'package:moonbase_skeleton/features/bases/presentation/providers/base_providers.dart';
import 'package:moonbase_skeleton/features/bases/domain/usecases/create_base.dart';
import 'package:moonbase_skeleton/features/bases/domain/usecases/join_base.dart';
import 'package:moonbase_skeleton/features/bases/domain/usecases/update_base.dart';
import 'package:moonbase_skeleton/features/bases/domain/usecases/delete_base.dart';
import 'package:moonbase_skeleton/features/bases/domain/usecases/list_bases.dart';
import 'package:moonbase_skeleton/features/auth/presentation/providers/current_user_id_provider.dart';
import 'package:moonbase_skeleton/core/user_color_utils.dart';
import 'package:moonbase_skeleton/core/ids.dart';

/// Provider for listing bases using domain entities
final basesListProvider = FutureProvider<List<Base>>((ref) async {
  final currentUserId = ref.watch(currentUserIdProvider);
  if (currentUserId == null) {
    throw Exception('User not authenticated');
  }
  
  final listBases = ref.read(listBasesUseCaseProvider);
  final result = await listBases(ListBasesParams(currentUserId.uid));
  
  return result.fold(
    (failure) => throw Exception(failure.message),
    (bases) => bases,
  );
});

/// Provider for selected base using domain entities
final selectedBaseProvider = StateProvider<Base?>((ref) => null);

/// Provider that manages base selection with auto-selection of last accessed base.
/// Only uses last-accessed base if it belongs to the current user's bases (no cross-user leak).
final effectiveSelectedBaseProvider = Provider<Base?>((ref) {
  final selectedBase = ref.watch(selectedBaseProvider);
  final lastAccessedBase = ref.watch(lastAccessedBaseProvider);
  final basesAsync = ref.watch(basesListProvider);

  if (selectedBase != null) {
    return selectedBase;
  }

  final last = lastAccessedBase.value;
  if (last == null) return null;

  // Only use last-accessed base if it is in the current user's list
  final userBases = basesAsync.valueOrNull ?? [];
  final belongsToCurrentUser = userBases.any((b) => b.id == last.id);
  return belongsToCurrentUser ? last : null;
});

/// Provider for last accessed base (scoped to current user)
final lastAccessedBaseProvider = FutureProvider<Base?>((ref) async {
  final currentUserId = ref.watch(currentUserIdProvider);
  if (currentUserId == null) return null;
  final baseRepository = ref.read(baseRepositoryProvider);
  final result = await baseRepository.getLastAccessedBase(UserId(currentUserId));
  return result.fold(
    (failure) => null,
    (base) => base,
  );
});

/// Provider for sidebar view model
final sidebarVmProvider = Provider<SidebarVM>((ref) {
  final basesAsync = ref.watch(basesListProvider);
  final selectedBase = ref.watch(selectedBaseProvider);

  return basesAsync.when(
    data: (bases) => SidebarVM(
      bases: bases,
      selectedBase: selectedBase,
      isLoading: false,
      hasError: false,
      errorMessage: null,
    ),
    loading: () => SidebarVM(
      bases: [],
      selectedBase: selectedBase,
      isLoading: true,
      hasError: false,
      errorMessage: null,
    ),
    error: (error, stack) => SidebarVM(
      bases: [],
      selectedBase: selectedBase,
      isLoading: false,
      hasError: true,
      errorMessage: error.toString(),
    ),
  );
});

/// Provider for base tile view models
final baseTileVmProvider = Provider.family<BaseTileVM?, String>((ref, baseId) {
  final sidebarVm = ref.watch(sidebarVmProvider);
  final currentUserId = ref.watch(currentUserIdProvider);
  
  if (sidebarVm.isLoading || sidebarVm.hasError) return null;
  
  try {
    final base = sidebarVm.bases.firstWhere((b) => b.id.value == baseId);
    final isSelected = sidebarVm.selectedBase?.id == base.id;
    final isOwner = currentUserId != null && base.ownerUserId == currentUserId.uid;
    final avatarColor = UserColorUtils.getColorForUserId(base.id.value);
    
    return BaseTileVM.fromBase(
      base,
      isSelected: isSelected,
      isOwner: isOwner,
      avatarColor: avatarColor,
    );
  } catch (e) {
    return null;
  }
});

/// Provider for creating bases. Returns the created [Base] on success so callers can select it.
final createBaseProvider = FutureProvider.family<Base?, String>((ref, baseName) async {
  final createBase = ref.read(createBaseUseCaseProvider);
  final currentUserId = ref.read(currentUserIdProvider);

  if (currentUserId == null) {
    throw Exception('User not authenticated');
  }

  final result = await createBase(CreateBaseParams(
    name: baseName,
    ownerUserId: currentUserId.uid,
  ));

  return result.fold<Base?>(
    (failure) => throw Exception(failure.message),
    (base) => base,
  );
});

/// Provider for joining bases with invite code
final joinBaseWithCodeProvider = FutureProvider.family<void, String>((ref, inviteCode) async {
  final joinBase = ref.read(joinBaseUseCaseProvider);
  final currentUserId = ref.read(currentUserIdProvider);
  
  if (currentUserId == null) {
    throw Exception('User not authenticated');
  }
  
  final result = await joinBase(JoinBaseParams(
    inviteCode: inviteCode,
    userId: currentUserId.uid,
  ));
  
  result.fold(
    (failure) => throw Exception(failure.message),
    (_) {
      // Refresh the bases list after successful join
      ref.refresh(basesListProvider);
    },
  );
});

/// Provider for updating bases
final updateBaseProvider = FutureProvider.family<void, UpdateBaseParams>((ref, params) async {
  final updateBase = ref.read(updateBaseUseCaseProvider);
  final currentUserId = ref.read(currentUserIdProvider);
  
  if (currentUserId == null) {
    throw Exception('User not authenticated');
  }
  
  final result = await updateBase(UpdateBaseParams(
    baseId: params.baseId,
    name: params.name,
    requesterUserId: currentUserId.uid,
  ));
  
  result.fold(
    (failure) => throw Exception(failure.message),
    (_) => null,
  );
});

/// Provider for deleting bases
final deleteBaseProvider = FutureProvider.family<void, String>((ref, baseId) async {
  final deleteBase = ref.read(deleteBaseUseCaseProvider);
  final currentUserId = ref.read(currentUserIdProvider);
  
  if (currentUserId == null) {
    throw Exception('User not authenticated');
  }
  
  final result = await deleteBase(DeleteBaseParams(
    baseId: baseId.bid,
    requesterUserId: currentUserId.uid,
  ));
  
  result.fold(
    (failure) => throw Exception(failure.message),
    (_) => null,
  );
});
