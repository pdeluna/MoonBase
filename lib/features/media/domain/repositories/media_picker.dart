import 'package:moonbase_skeleton/features/media/domain/entities/media_pick_request.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';

/// Surfaces media to the app from outside it (camera, gallery, future drag-and-
/// drop on desktop, etc.).
///
/// Implementations validate against `MediaConstraints` and persist via
/// `MediaStorage` before returning a fully-formed `MediaRef`. Callers do not
/// see raw `XFile`/`File`/`Uint8List` types.
///
/// Phase 3 implementation: `ImagePickerMediaPicker` — a thin wrapper around
/// the `image_picker` plugin. `captureFromCamera` is implemented today by
/// dispatching to `image_picker` with `ImageSource.camera` and is shaped so a
/// future custom in-app camera surface can be a one-file alternative
/// implementation of this same port (`InAppCameraMediaPicker`) without any
/// call-site changes in chat / stories / posts.
///
/// Contract:
///
/// - Returns `null` when the user cancels (any source).
/// - Throws a typed `Failure` (e.g. `MediaTooLargeFailure`,
///   `MediaTooLongFailure`, `MediaUnsupportedFailure`,
///   `PermissionDeniedFailure`) when something is wrong; never returns a
///   half-validated `MediaRef`.
///
/// See `docs/PHASE3_DOD_ACTION_LIST.md` §0.3.3.
abstract class MediaPicker {
  /// Pick an image from the OS gallery.
  Future<MediaRef?> pickImage(MediaPickRequest request);

  /// Pick up to [limit] images from the OS gallery in one session.
  ///
  /// Returns an empty list when the user cancels. Each item is fully validated
  /// and persisted before being included. Throws typed [Failure] values on
  /// validation or permission errors (same contract as [pickImage]).
  Future<List<MediaRef>> pickMultipleImages(
    MediaPickRequest request, {
    required int limit,
  });

  /// Pick a video from the OS gallery.
  Future<MediaRef?> pickVideo(MediaPickRequest request);

  /// Capture a photo or video using the OS camera. Dispatches by
  /// `request.kind` (image vs video).
  ///
  /// A future `InAppCameraMediaPicker` can replace this with a custom Flutter
  /// capture surface; same return type, same failure modes.
  Future<MediaRef?> captureFromCamera(MediaPickRequest request);
}
