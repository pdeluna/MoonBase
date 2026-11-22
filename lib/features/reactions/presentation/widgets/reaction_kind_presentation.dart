import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction_kind.dart';

/// Presentation-only glyphs/labels for the six kinds. The domain enum
/// stays glyph-free so the wire value and the visual can evolve apart.
extension ReactionKindPresentation on ReactionKind {
  String get emoji => switch (this) {
        ReactionKind.like => '👍',
        ReactionKind.heart => '❤️',
        ReactionKind.laugh => '😂',
        ReactionKind.wow => '😮',
        ReactionKind.sad => '😢',
        ReactionKind.fire => '🔥',
      };

  String get label => switch (this) {
        ReactionKind.like => 'Like',
        ReactionKind.heart => 'Heart',
        ReactionKind.laugh => 'Laugh',
        ReactionKind.wow => 'Wow',
        ReactionKind.sad => 'Sad',
        ReactionKind.fire => 'Fire',
      };
}
