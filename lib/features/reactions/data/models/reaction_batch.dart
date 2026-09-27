import 'package:moonbase_skeleton/features/reactions/data/models/reaction_model.dart';

/// One snapshot of reactions plus whether it came from cache.
/// [fromCache] is `snap.metadata.isFromCache` alone (as `ChatMessageBatch`).
class ReactionBatch {
  const ReactionBatch({required this.reactions, required this.fromCache});

  final List<ReactionModel> reactions;
  final bool fromCache;
}
