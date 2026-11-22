import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction_feed.dart';
import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction_target.dart';
import 'package:moonbase_skeleton/features/reactions/domain/repositories/reaction_repository.dart';

/// One listener per `(base, targetKind)` — the chat screen subscribes once
/// with `ReactionTargetKind.message` and joins by target id in its VM.
class WatchReactions {
  const WatchReactions(this.repo);

  final ReactionRepository repo;

  Stream<ReactionFeed> call(BaseId baseId, ReactionTargetKind targetKind) =>
      repo.watchFor(baseId: baseId, targetKind: targetKind);
}
