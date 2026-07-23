import 'package:flutter/foundation.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/core/sync_status.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';

/// MVP shape per Phase 3 DoD Section 2.1.1. Deliberately a narrower surface
/// than the legacy BaseSettings; the legacy class can be retired in Phase 4.
@immutable
class BaseSettings {
  const BaseSettings({
    required this.baseId,
    required this.updatedAt,
    required this.updatedByUserId,
    this.storiesEnabled = true,
    this.storiesArchiveEnabled = true,
    this.storyTtl = const Duration(hours: 24),
    this.maxMediaPerStory = 1,
  });

  final BaseId baseId;
  final bool storiesEnabled;
  final bool storiesArchiveEnabled;
  final Duration storyTtl;
  final int maxMediaPerStory;
  final DateTime updatedAt;
  final UserId updatedByUserId;

  BaseSettings copyWith({
    BaseId? baseId,
    bool? storiesEnabled,
    bool? storiesArchiveEnabled,
    Duration? storyTtl,
    int? maxMediaPerStory,
    DateTime? updatedAt,
    UserId? updatedByUserId,
  }) {
    return BaseSettings(
      baseId: baseId ?? this.baseId,
      storiesEnabled: storiesEnabled ?? this.storiesEnabled,
      storiesArchiveEnabled: storiesArchiveEnabled ?? this.storiesArchiveEnabled,
      storyTtl: storyTtl ?? this.storyTtl,
      maxMediaPerStory: maxMediaPerStory ?? this.maxMediaPerStory,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedByUserId: updatedByUserId ?? this.updatedByUserId,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BaseSettings &&
        other.baseId == baseId &&
        other.storiesEnabled == storiesEnabled &&
        other.storiesArchiveEnabled == storiesArchiveEnabled &&
        other.storyTtl == storyTtl &&
        other.maxMediaPerStory == maxMediaPerStory &&
        other.updatedAt == updatedAt &&
        other.updatedByUserId == updatedByUserId;
  }

  @override
  int get hashCode => Object.hash(
        baseId,
        storiesEnabled,
        storiesArchiveEnabled,
        storyTtl,
        maxMediaPerStory,
        updatedAt,
        updatedByUserId,
      );
}
//Start of Junior implementation
@immutable
class Stories {
  const Stories ({
    //"required" keyword prevents dart from setting a default value of "null" if caller function does not give a value
    required this.id,
    required this.baseId,
    required this.authorUserId,
    required this.media,
    this.caption,
    required this.storyTtl,
    required this.createdAt,
    this.archived = true,
    this.syncStatus = SyncStatus.synced,
  });
  //Variable type values are initialized during runtime using "final" keyword
  final StoryId id;
  final BaseId baseId;
  final UserId authorUserId;
  final MediaRef media;
  final String? caption;
  final Duration storyTtl;
  final DateTime createdAt;
  final bool archived;
  final SyncStatus syncStatus;
  
  //"copyWith" allows the values to be changed without having to manually set new values
  Stories copyWith({
    StoryId? id,
    BaseId? baseId,
    UserId? authorUserId,
    MediaRef? media,
    String? caption,
    Duration? storyTtl,
    DateTime? createdAt,
    bool? archived,
    SyncStatus? syncStatus,
  })

  //Values that are sent to caller
  {
    return Stories(
    /* structure of return values for future reference:
    contains 4 tokens: Variable, current Variable value, ??, Right hand value if null
    */
    id: id ?? this.id, 
    baseId: baseId ?? this.baseId,
    authorUserId: authorUserId ?? this.authorUserId,
    media: media ?? this.media,
    caption: caption ?? this.caption,
    storyTtl: storyTtl ?? this.storyTtl,
    createdAt: createdAt ?? this.createdAt);
    }

    //checks if values are identical asychronously  
    @override 
    bool operator ==(Object other){
      if (identical (this,other)) return true;
      return other is Stories &&
      other.id == id &&
      other.baseId == baseId &&
      other.authorUserId == authorUserId &&
      other.media == media &&
      other.caption == caption &&
      other.storyTtl == storyTtl &&
      other.createdAt == createdAt;
      /*other.archived == archived &&
      other.syncStatus == syncStatus;
      is this required for Boolean check?*/

    }

    /*creates a hash for all present values/objects 
    requires previous override boolean function s.t. in cases of collisions 
    values of the entity can be checked to ensure the values of the arguement/class are the same.
    The function below then hashes the object. Both function work in tandem to reduce chances of collision.
    */
    @override
    int get hashCode => Object.hash(
      id,
      baseId,
      authorUserId,
      media,
      caption,
      storyTtl,
      createdAt,
      //archived,
      //syncStatus, 
    );
}