import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction_feed.dart';
import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction_kind.dart';
import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction_target.dart';

/// Port for the generalized reactions system (chat today; stories,
/// comments, posts, events reserved). No Firebase types.
///
/// Writes are **unbounded** (R3 posture — same as chat send); the caller
/// renders optimistically and rolls back on `Left`.
abstract class ReactionRepository {
  /// Upsert `me`'s reaction on [target] to [kind] (create or replace).
  Future<Either<Failure, void>> react({
    required BaseId baseId,
    required ReactionTarget target,
    required UserId userId,
    required ReactionKind kind,
  });

  /// Remove `me`'s reaction on [target]; no-op when absent.
  Future<Either<Failure, void>> unreact({
    required BaseId baseId,
    required ReactionTarget target,
    required UserId userId,
  });

  /// Live reactions for every target of [targetKind] in [baseId], newest
  /// first, plus cache-vs-live freshness. Errors are delivered as typed
  /// `Failure`s on the stream (never raw SDK exceptions).
  Stream<ReactionFeed> watchFor({
    required BaseId baseId,
    required ReactionTargetKind targetKind,
  });
}
