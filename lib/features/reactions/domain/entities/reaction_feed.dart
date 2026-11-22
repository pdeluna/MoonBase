import 'package:flutter/foundation.dart';
import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction.dart';

/// Whether the reactions snapshot came from the local cache or the server.
/// Mirrors `ChatFreshness`; deliberately its own enum (one per feature).
enum ReactionFreshness { cached, live }

/// All reactions for one `(base, targetKind)` plus freshness — the payload
/// of the single chat-screen listener. Grouping per target happens in the
/// VM (`ReactionGroup.from`), never here.
@immutable
class ReactionFeed {
  const ReactionFeed({required this.reactions, required this.freshness});

  final List<Reaction> reactions;
  final ReactionFreshness freshness;

  @override
  bool operator ==(Object other) =>
      other is ReactionFeed &&
      other.freshness == freshness &&
      listEquals(other.reactions, reactions);

  @override
  int get hashCode => Object.hash(freshness, Object.hashAll(reactions));
}
