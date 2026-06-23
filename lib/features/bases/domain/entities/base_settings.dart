import 'package:flutter/foundation.dart';
// TODO(stories Step 1.2): uncomment the IDs import once you start declaring
// `BaseId baseId` and `UserId updatedByUserId`. The import is intentionally
// commented to keep `unused_import` quiet on the scaffold stub.
//
// import 'package:moonbase_skeleton/core/ids.dart';

/// Owner-configurable settings for a single base.
///
/// **Scaffold stub** — see `assignments/STORIES_FIRST_STEPS.md` Section 3.2.
///
/// Reference pattern: `lib/features/media/domain/entities/media_ref.dart` is
/// the canonical `@immutable` value-class shape in this project. Mirror its
/// constructor / fields / copyWith / `==` / hashCode / toString layout
/// exactly. Do **not** copy the legacy `lib/legacy/models/base_settings.dart`
/// shape — its field surface is much wider than the Phase 3 DoD MVP.
///
/// Required fields (Phase 3 DoD Section 2.1.1, MVP scope):
///
/// - `BaseId baseId`
/// - `bool storiesEnabled` (default `true`)
/// - `bool storiesArchiveEnabled` (default `true`)
/// - `Duration storyTtl` (default `Duration(hours: 24)`)
/// - `int maxMediaPerStory` (default `1`)
/// - `DateTime updatedAt`
/// - `UserId updatedByUserId`
///
/// Required behaviour:
///
/// - `const` constructor (lint: `prefer_const_constructors_in_immutables`).
/// - Constructor declared **before** the field declarations (lint:
///   `sort_constructors_first`).
/// - `copyWith`, `==`, `hashCode`, optional `toString`.
/// - **No** `fromJson` / `toMap`. Serialisation belongs on
///   `BaseSettingsModel` in the data layer.
@immutable
class BaseSettings {
  // TODO(stories Step 1.2): replace this placeholder constructor with the
  // real one taking all seven fields above (six required + the defaults).
  // Once the real constructor exists, delete this stub.
  const BaseSettings();

  // TODO(stories Step 1.2): declare the seven fields below the constructor.
  // Use the typed IDs from `package:moonbase_skeleton/core/ids.dart` — never
  // raw `String` for `baseId` or `updatedByUserId`.

  // TODO(stories Step 1.2): implement `copyWith`. Mirror the shape used by
  // `MediaRef.copyWith` (one nullable named parameter per field, falling
  // back to `this.field`).

  // TODO(stories Step 1.2): implement `==` and `hashCode`. The project does
  // **not** depend on `Equatable`; write them by hand. Use
  // `Object.hash(...)` for the hash, and compare every field explicitly in
  // `operator ==`.

  // TODO(stories Step 1.2): optional `toString()` for debug logs. Match the
  // style in `MediaRef.toString`.
}
