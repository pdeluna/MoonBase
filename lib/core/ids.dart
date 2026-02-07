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

/// Nice test/dev ergonomics
extension IdShortcuts on String {
  UserId get uid => UserId(this);
  BaseId get bid => BaseId(this);
  MessageId get mid => MessageId(this);
  InviteId get iid => InviteId(this);
}
