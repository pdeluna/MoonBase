abstract class Failure {
  const Failure(this.message);

  final String message;

  @override
  String toString() => '$runtimeType($message)';
}
class NetworkFailure extends Failure { const NetworkFailure([super.message = 'Network error']); }
class CacheFailure   extends Failure { const CacheFailure([super.message = 'Cache error']); }
class UnknownFailure extends Failure { const UnknownFailure([super.message = 'Unknown error']); }
class ValidationFailure extends Failure { const ValidationFailure([super.message = 'Validation error']);
}

// ---------------------------------------------------------------------------
// Phase 3 (content features) — added in foundation slice.
// See docs/PHASE3_DOD_ACTION_LIST.md §0.2.3.
// ---------------------------------------------------------------------------

/// Picked media exceeds the byte cap from `MediaConstraints`.
class MediaTooLargeFailure extends Failure {
  const MediaTooLargeFailure([super.message = 'Media exceeds the maximum size.']);
}

/// Picked video exceeds the duration cap from `MediaConstraints`.
class MediaTooLongFailure extends Failure {
  const MediaTooLongFailure([super.message = 'Video exceeds the maximum length.']);
}

/// Picked media is of a type the app does not handle this phase
/// (e.g. unsupported codec, unknown MIME).
class MediaUnsupportedFailure extends Failure {
  const MediaUnsupportedFailure([super.message = 'Unsupported media type.']);
}

/// The OS denied a permission required to complete the operation
/// (camera, microphone, photo library, etc.). Surfaces should offer the user
/// an affordance to open OS settings.
class PermissionDeniedFailure extends Failure {
  const PermissionDeniedFailure([super.message = 'Permission denied.']);
}
