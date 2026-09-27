import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonbase_skeleton/features/reactions/domain/repositories/reaction_repository.dart';
import 'package:moonbase_skeleton/features/reactions/domain/usecases/toggle_reaction.dart';
import 'package:moonbase_skeleton/features/reactions/domain/usecases/watch_reactions.dart';

/// Override at app root with a concrete repo (`main.dart`).
final reactionRepositoryProvider = Provider<ReactionRepository>((ref) {
  throw UnimplementedError('Provide ReactionRepository in app wiring');
});

final toggleReactionUseCaseProvider =
    Provider((ref) => ToggleReaction(ref.read(reactionRepositoryProvider)));

final watchReactionsUseCaseProvider =
    Provider((ref) => WatchReactions(ref.read(reactionRepositoryProvider)));
