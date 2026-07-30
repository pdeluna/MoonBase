import 'package:flutter/foundation.dart';
// TODO(stories Step 2): uncomment these imports as you add fields that use
// them. They are listed here, commented out, so you can see at a glance
// which imports are expected and so the scaffold stub stays lint-clean.
//
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/core/sync_status.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';

/// Domain entity representing one ephemeral story published to a base.
///
/// **Scaffold stub** — see `assignments/STORIES_FIRST_STEPS.md` Section 4.
///
/// Reference pattern: `lib/features/media/domain/entities/media_ref.dart` for
/// `@immutable` value-class shape; `lib/features/chat/domain/entities/message.dart`
/// for a slightly simpler example with the same `==`/`hashCode`/`toString`
/// convention.
///
/// Required fields (Phase 3 DoD Section 2.2.1):
///
/// - `StoryId id`
/// - `BaseId baseId`
/// - `UserId authorUserId`
/// - `MediaRef media`  **(singular — Stories cap at one media per story; do
///   NOT use `List<MediaRef>`. Posts have a list; Stories never do.)**
/// - `String? caption`
/// - `Duration ttl`
/// - `DateTime createdAt`
/// - `bool archived` (default `false`)
/// - `SyncStatus syncStatus` (default `SyncStatus.synced`)
///
/// Required behaviour:
///
/// - `const` constructor declared **before** field declarations.
/// - `copyWith`, `==`, `hashCode`, optional `toString`.
/// - A computed getter:
///
///   ```dart
///   bool get isExpired => DateTime.now().isAfter(createdAt.add(ttl));
///   ```
///
///   No clock injection at this stage; the repository sweep is the only
///   production caller.
///
/// Three pitfalls the first-steps guide flags explicitly:
///
/// 1. `MediaRef media` is **singular**. `List<MediaRef>` means you misread
///    the DoD.
/// 2. `syncStatus` defaults to `SyncStatus.synced`. Phase 4's outbox sync
///    relies on this being the local-only default, so do not omit the field.
/// 3. `archived` and `isExpired` are **orthogonal**. `isExpired` checks the
///    clock only; the repository sweep flips `archived` on expired rows
///    when `storiesArchiveEnabled` is true.
@immutable
class Story {
  // TODO(stories Step 2): replace this placeholder constructor with the real
  // one taking all nine fields above (seven required + the two with
  // defaults). Constructor first, fields after — lint rule
  // `sort_constructors_first` is enforced project-wide.
  const Story({
      required this.id,
      required this.baseId,
      required this.authorUserId,
      required this.media,
      required this.caption,
      required this.ttl,
      required this.createdAt,
      this.archived = true,
      this.syncStatus = SyncStatus.synced,
    }
  );

  final StoryId id;
  final BaseId baseId;
  final UserId authorUserId;
  final MediaRef media;
  final String? caption;
  final Duration ttl;
  final DateTime createdAt;
  bool get isExpired; //in order to use the 'get' method, final must be removed
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
    bool? isExpired,
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
      isExpired: isExpired ?? this.isExpired,
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
    other.createdAt == createdAt &&
    other.isExpired == isExpired; //&&
    //other.archived == archived &&
    //other.syncStatus == syncStatus;
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
    isExpired,
    //archived,
    //syncStatus,
  );

  @override
  bool get isExpired => DateTime.now().isAfter(createdAt.add(ttl));



  // TODO(stories Step 2): declare the nine fields below. Use typed IDs from
  // `package:moonbase_skeleton/core/ids.dart` and `SyncStatus` from
  // `package:moonbase_skeleton/core/sync_status.dart`. **Never** raw `String`
  // for IDs.

  // TODO(stories Step 2): add the `isExpired` getter exactly as documented
  // in the class doc-comment above.

  // TODO(stories Step 2): implement `copyWith`, `operator ==`, `hashCode`,
  // and (optionally) `toString`. Mirror `MediaRef`'s pattern verbatim.
}
