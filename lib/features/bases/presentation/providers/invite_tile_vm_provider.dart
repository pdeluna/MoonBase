import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonbase_skeleton/features/bases/presentation/viewmodels/invite_tile_vm.dart';
import 'package:moonbase_skeleton/features/bases/presentation/providers/invite_providers.dart';
import 'package:moonbase_skeleton/legacy/providers/bases_provider.dart';

final inviteTileVmProvider = Provider.family<InviteTileVM?, String>((ref, inviteId) {
  // For now, we'll get the invite from the base invites provider
  // In a real app, this would use a more efficient inviteByIdProvider
  
  // We need to find the invite - for now, let's get it from the current base's invites
  // This is not ideal but works for the current architecture
  final selectedBase = ref.watch(effectiveSelectedBaseProvider);
  if (selectedBase == null) return null;
  
  final invitesAsync = ref.watch(baseInvitesProvider(selectedBase.id));
  
  return invitesAsync.when(
    data: (invites) {
      try {
        final invite = invites.firstWhere((i) => i.id.value == inviteId);
        return InviteTileVM.fromInvite(invite);
      } catch (e) {
        return null;
      }
    },
    loading: () => null,
    error: (_, __) => null,
  );
});
