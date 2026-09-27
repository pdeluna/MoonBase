import 'package:moonbase_skeleton/features/reactions/data/models/reaction_batch.dart';
import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction_kind.dart';
import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction_target.dart';

/// Reactions I/O. Implementations throw; `ReactionRepositoryImpl` guards.
abstract class ReactionDataSource {
  /// `set()` on the deterministic id — create or replace kind.
  Future<void> react({
    required String baseId,
    required ReactionTarget target,
    required String uid,
    required ReactionKind kind,
  });

  /// `delete()` on the deterministic id — toggle off.
  Future<void> unreact({
    required String baseId,
    required ReactionTarget target,
    required String uid,
  });

  /// Live batches for every reaction of [targetKind] in [baseId], newest
  /// first. May emit SDK errors (e.g. `failed-precondition` before the
  /// composite index is Enabled); the repository maps them.
  Stream<ReactionBatch> watchFor({
    required String baseId,
    required ReactionTargetKind targetKind,
  });
}
