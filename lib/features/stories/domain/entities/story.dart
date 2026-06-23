import 'package:flutter/foundation.dart';
// TODO(stories Step 2): uncomment these imports as you add fields that use
// them. They are listed here, commented out, so you can see at a glance
// which imports are expected and so the scaffold stub stays lint-clean.
//
// import 'package:moonbase_skeleton/core/ids.dart';
// import 'package:moonbase_skeleton/core/sync_status.dart';
// import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';

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
  const Story();

  // TODO(stories Step 2): declare the nine fields below. Use typed IDs from
  // `package:moonbase_skeleton/core/ids.dart` and `SyncStatus` from
  // `package:moonbase_skeleton/core/sync_status.dart`. **Never** raw `String`
  // for IDs.

  // TODO(stories Step 2): add the `isExpired` getter exactly as documented
  // in the class doc-comment above.

  // TODO(stories Step 2): implement `copyWith`, `operator ==`, `hashCode`,
  // and (optionally) `toString`. Mirror `MediaRef`'s pattern verbatim.
}
