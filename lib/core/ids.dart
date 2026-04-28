import 'package:flutter/foundation.dart';

@immutable
class UserId {
  const UserId(this.value) : assert(value != '');
  final String value;

  @override bool operator ==(Object other) => other is UserId && other.value == value;
  @override int get hashCode => value.hashCode;
  @override String toString() => value;
}

@immutable
class BaseId {
  const BaseId(this.value) : assert(value != '');
  final String value;

  @override bool operator ==(Object other) => other is BaseId && other.value == value;
  @override int get hashCode => value.hashCode;
  @override String toString() => value;
}

@immutable
class MessageId {
  const MessageId(this.value) : assert(value != '');
  final String value;
  
  @override bool operator ==(Object other) => other is MessageId && other.value == value;
  @override int get hashCode => value.hashCode;
  @override String toString() => value;
}

@immutable
class InviteId {
  const InviteId(this.value) : assert(value != '');
  final String value;
  
  @override bool operator ==(Object other) => other is InviteId && other.value == value;
  @override int get hashCode => value.hashCode;
  @override String toString() => value;
}

// ---------------------------------------------------------------------------
// Phase 3 (content features) — added in foundation slice.
// See docs/PHASE3_DOD_ACTION_LIST.md §0.2.2.
// ---------------------------------------------------------------------------

@immutable
class MediaId {
  const MediaId(this.value) : assert(value != '');
  final String value;

  @override bool operator ==(Object other) => other is MediaId && other.value == value;
  @override int get hashCode => value.hashCode;
  @override String toString() => value;
}

@immutable
class StoryId {
  const StoryId(this.value) : assert(value != '');
  final String value;

  @override bool operator ==(Object other) => other is StoryId && other.value == value;
  @override int get hashCode => value.hashCode;
  @override String toString() => value;
}

@immutable
class PostId {
  const PostId(this.value) : assert(value != '');
  final String value;

  @override bool operator ==(Object other) => other is PostId && other.value == value;
  @override int get hashCode => value.hashCode;
  @override String toString() => value;
}

@immutable
class ReactionId {
  const ReactionId(this.value) : assert(value != '');
  final String value;

  @override bool operator ==(Object other) => other is ReactionId && other.value == value;
  @override int get hashCode => value.hashCode;
  @override String toString() => value;
}

/// Nice test/dev ergonomics.
///
/// `MediaId` deliberately has no shortcut: `.mid` is taken by `MessageId` and
/// `MediaId` collides with it semantically. Use the explicit constructor.
extension IdShortcuts on String {
  UserId get uid => UserId(this);
  BaseId get bid => BaseId(this);
  MessageId get mid => MessageId(this);
  InviteId get iid => InviteId(this);
  StoryId get sid => StoryId(this);
  PostId get pid => PostId(this);
  ReactionId get rid => ReactionId(this);
}
