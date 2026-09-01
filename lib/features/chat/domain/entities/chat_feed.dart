import 'package:moonbase_skeleton/features/chat/domain/entities/chat_freshness.dart';
import 'package:moonbase_skeleton/features/chat/domain/entities/message.dart';

/// Messages for a base plus whether that list is cached or live.
///
/// The stream payload analog of R4's `AsyncValue<User?>`: do not flatten
/// to `List<Message>` before the UI, or freshness has nowhere to live.
class ChatFeed {
  const ChatFeed({
    required this.messages,
    required this.freshness,
  });

  final List<Message> messages;
  final ChatFreshness freshness;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatFeed &&
        other.freshness == freshness &&
        _listEquals(other.messages, messages);
  }

  @override
  int get hashCode => Object.hash(freshness, Object.hashAll(messages));
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
