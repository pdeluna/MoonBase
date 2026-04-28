/// The kinds of media MoonBase persists and renders.
///
/// Phase 3 supports [image] and [video] only. The legacy `MediaType` enum at
/// `lib/legacy/models/enums.dart` also includes `link`; this domain enum
/// intentionally does not, to avoid coupling the new feature to the legacy
/// model and to keep the renderer surface small.
///
/// See `docs/PHASE3_DOD_ACTION_LIST.md` §0.3.2.
enum MediaType {
  image,
  video,
}
