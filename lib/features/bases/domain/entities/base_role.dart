/// Domain-layer enum describing a member's authority within a base.
///
/// **Scaffold stub** — see `assignments/STORIES_FIRST_STEPS.md` Section 3.1.
///
/// Reference pattern: there is no exact mirror for an enum in the chat slice;
/// the closest analog is `lib/features/media/domain/entities/media_type.dart`
/// (a flat domain-layer enum with no JSON, no business logic in the enum
/// itself).
///
/// The legacy version at `lib/legacy/models/enums.dart` is **not** the spec.
/// Use the MVP shape from `docs/PHASE3_DOD_ACTION_LIST.md` Section 2.1.2 only:
/// three values, plus the convenience getter so use cases can ask one
/// question instead of comparing twice.
enum BaseRole {
  // TODO(stories Step 1.1): replace this placeholder with the real MVP
  // values. Required values, in this order, per the feature request:
  //   - owner
  //   - admin
  //   - member
  // Delete `_unused` (and the ignore comment below) once you add them.
  // ignore: unused_field
  _unused;

  // TODO(stories Step 1.1): add a convenience getter so use cases can write
  // `if (role.isOwnerOrAdmin) { ... }` instead of comparing twice:
  //
  //   bool get isOwnerOrAdmin => this == BaseRole.owner || this == BaseRole.admin;
  //
  // Reasoning: every use case that gates on permission asks the same
  // question. Centralising the predicate keeps the call sites readable and
  // makes future role additions (`viewer`, `moderator`, ...) a single-file
  // change.
}
