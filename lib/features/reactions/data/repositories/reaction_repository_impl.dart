import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/error_mapper.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/reactions/data/datasources/reaction_data_source.dart';
import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction_feed.dart';
import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction_kind.dart';
import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction_target.dart';
import 'package:moonbase_skeleton/features/reactions/domain/repositories/reaction_repository.dart';

/// Copy for the pre-index state. The composite index is a manual deploy
/// (plan §10); until the Console shows it Enabled every live query fails
/// with `failed-precondition`. Surfaced as a typed `Failure` so the chat
/// screen renders "no chips" instead of crashing.
const String kReactionsIndexNotReadyMessage =
    'Reactions are not available yet (index still building).';

class ReactionRepositoryImpl implements ReactionRepository {
  ReactionRepositoryImpl({required this.source});

  final ReactionDataSource source;

  // Writes are unbounded (R3 posture, same as chat send) — guardVoid, not
  // guardWithTimeout. Do not add a write timeout here (trigger #12).
  @override
  Future<Either<Failure, void>> react({
    required BaseId baseId,
    required ReactionTarget target,
    required UserId userId,
    required ReactionKind kind,
  }) =>
      guardVoid(() => source.react(
            baseId: baseId.value,
            target: target,
            uid: userId.value,
            kind: kind,
          ));

  @override
  Future<Either<Failure, void>> unreact({
    required BaseId baseId,
    required ReactionTarget target,
    required UserId userId,
  }) =>
      guardVoid(() => source.unreact(
            baseId: baseId.value,
            target: target,
            uid: userId.value,
          ));

  @override
  Stream<ReactionFeed> watchFor({
    required BaseId baseId,
    required ReactionTargetKind targetKind,
  }) {
    return source
        .watchFor(baseId: baseId.value, targetKind: targetKind)
        .map(
          (batch) => ReactionFeed(
            reactions: batch.reactions
                .map((m) => m.toEntity())
                .toList(growable: false),
            freshness: batch.fromCache
                ? ReactionFreshness.cached
                : ReactionFreshness.live,
          ),
        )
        .transform(
          StreamTransformer<ReactionFeed, ReactionFeed>.fromHandlers(
            handleError: (error, stackTrace, sink) =>
                sink.addError(mapStreamError(error), stackTrace),
          ),
        );
  }

  /// Stream-side analogue of `mapException`: the one Firestore code this
  /// feature adds meaning to is `failed-precondition` (missing index).
  static Failure mapStreamError(Object error) {
    if (error is FirebaseException && error.code == 'failed-precondition') {
      return const UnknownFailure(kReactionsIndexNotReadyMessage);
    }
    return mapException(error);
  }
}
