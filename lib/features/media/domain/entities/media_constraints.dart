/// Central caps applied by `PickAndPersistMedia` (and any custom picker) to
/// keep the closed-circle UX predictable and keep storage usage bounded.
///
/// Tunable in one place; if a future base-level setting overrides any of these
/// (e.g. `BaseSettings.maxMediaPerStory`), the override is read at the use
/// case layer and merged with these defaults.
///
/// See `docs/PHASE3_DOD_ACTION_LIST.md` §0.3.1.
class MediaConstraints {
  const MediaConstraints({
    this.imageMaxBytes = imageMaxBytesDefault,
    this.videoMaxBytes = videoMaxBytesDefault,
    this.videoMaxDuration = videoMaxDurationDefault,
    this.maxMediaPerMessage = maxMediaPerMessageDefault,
    this.maxMediaPerPost = maxMediaPerPostDefault,
  });

  final int imageMaxBytes;
  final int videoMaxBytes;
  final Duration videoMaxDuration;
  final int maxMediaPerMessage;
  final int maxMediaPerPost;

  static const int imageMaxBytesDefault = 10 * 1024 * 1024; // 10 MB per image (matches storage.rules)
  static const int videoMaxBytesDefault = 50 * 1024 * 1024; // 50 MB
  static const Duration videoMaxDurationDefault = Duration(seconds: 30);
  static const int maxMediaPerMessageDefault = 4;
  static const int maxMediaPerPostDefault = 10;

  /// The default constraints used wherever a base-level override is not
  /// available. Use as `MediaConstraints.defaults` for clarity at call sites.
  static const MediaConstraints defaults = MediaConstraints();
}
