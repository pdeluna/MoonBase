import 'package:flutter/foundation.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/core/sync_status.dart';
// import 'package:moonbase_skeleton/features/bases/domain/entities/base.dart'; // missing functionality from scaffolding? will check during testing. 
// above import actually not needed! - p
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';

@immutable
class Story {
  const Story({
      required this.id,
      required this.baseId,
      required this.authorUserId,
      required this.media,
      //required this.caption, // lets make captions not required ! - p
      required this.ttl,
      required this.createdAt,
      this.caption,
      this.archived = false, // i know i said status didn't matter (still true) just to be safe let's keep it false since the archive feature is not built yet ;p
      this.syncStatus = SyncStatus.synced, //default sync status must exist so phase 4 will be a one-line change - p
    }
  );

  final StoryId id;
  final BaseId baseId;
  final UserId authorUserId;
  final MediaRef media;
  final String? caption;
  final Duration ttl;
  final DateTime createdAt;
  bool get isExpired => DateTime.now().isAfter(createdAt.add(ttl)); // -> checks if story is expired 
  final bool archived;
  final SyncStatus syncStatus;

  Story copyWith({
    StoryId? id,
    BaseId? baseId,
    UserId? authorUserId,
    MediaRef? media,
    String? caption,
    Duration? ttl,
    DateTime? createdAt,
    bool? archived,
    SyncStatus? syncStatus,
  }) {
    return Story(
      id: id ?? this.id,
      baseId: baseId ?? this.baseId,
      authorUserId: authorUserId ?? this.authorUserId,
      media: media ?? this.media,
      caption: caption ?? this.caption,
      ttl: ttl ?? this.ttl,
      createdAt: createdAt ?? this.createdAt,
      archived: archived ?? this.archived,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Story &&
    other.id == id &&
    other.baseId == baseId &&
    other.authorUserId == authorUserId &&
    other.media == media &&
    other.caption == caption &&
    other.ttl == ttl &&
    other.createdAt == createdAt; && // safe to include these, we will use these values for unit tests - p
    other.archived == archived &&
    other.syncStatus == syncStatus;
  }

  @override
  int get hashCode => Object.hash(
    id,
    baseId,
    authorUserId,
    media,
    caption,
    ttl,
    createdAt,
    archived, // included these similar to == operator - p
    syncStatus, 
  );
}
