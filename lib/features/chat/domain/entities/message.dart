import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/core/sync_status.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';

/// A single chat message belonging to a base.
///
/// Phase 3 (Slice A) adds two fields to the Phase 2 shape:
///
/// - [media]: zero or more `MediaRef`s attached to the message. Capped per
///   message by `MediaConstraints.maxMediaPerMessageDefault` (default 4) —
///   the cap is enforced in `SendMessage`, not on the entity itself.
/// - [syncStatus]: Phase 4 outbox-sync support. Always
///   [SyncStatus.synced] while the app is local-only; future Phase 4 writes
///   start as [SyncStatus.localOnly] and the sync service replays them.
///
/// See `docs/PHASE3_DOD_ACTION_LIST.md` Section 1.1.1.
class Message {
  const Message({
    required this.id,
    required this.baseId,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.media = const [],
    this.syncStatus = SyncStatus.synced,
  });

  final MessageId id;
  final BaseId baseId;
  final UserId userId;
  final String content;
  final DateTime createdAt;
  final List<MediaRef> media;
  final SyncStatus syncStatus;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Message &&
        other.id == id &&
        other.baseId == baseId &&
        other.userId == userId &&
        other.content == content &&
        other.createdAt == createdAt &&
        _listEquals(other.media, media) &&
        other.syncStatus == syncStatus;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      baseId,
      userId,
      content,
      createdAt,
      Object.hashAll(media),
      syncStatus,
    );
  }

  @override
  String toString() {
    return 'Message(id: $id, baseId: $baseId, userId: $userId, content: $content, '
        'createdAt: $createdAt, media: ${media.length} item(s), syncStatus: $syncStatus)';
  }
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
