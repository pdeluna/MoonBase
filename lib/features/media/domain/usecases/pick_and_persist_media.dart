import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/usecase.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_pick_request.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_type.dart';
import 'package:moonbase_skeleton/features/media/domain/repositories/media_picker.dart';

/// Picks a single media item from camera or gallery, validates it, persists it
/// via `MediaStorage`, and returns the resulting `MediaRef`.
///
/// This is a thin orchestrator on top of `MediaPicker`. The heavy lifting
/// (raw OS picker invocation, byte-cap enforcement, duration cap enforcement,
/// MIME sniffing, write through `MediaStorage`) lives in the picker
/// implementation, which keeps the use case trivially testable.
///
/// Contract:
///
/// - Returns `Right(MediaRef)` on success.
/// - Returns `Right(null)` when the user cancels the OS picker. Cancellation
///   is **not** an error.
/// - Returns `Left(Failure)` when validation fails (`MediaTooLargeFailure`,
///   `MediaTooLongFailure`, `MediaUnsupportedFailure`) or a permission is
///   denied (`PermissionDeniedFailure`).
///
/// See `docs/PHASE3_DOD_ACTION_LIST.md` §0.3.4.
class PickAndPersistMedia implements UseCase<MediaRef?, MediaPickRequest> {
  const PickAndPersistMedia(this.picker);

  final MediaPicker picker;

  @override
  Future<Either<Failure, MediaRef?>> call(MediaPickRequest params) async {
    try {
      final MediaRef? ref;
      if (params.source == MediaSource.camera) {
        ref = await picker.captureFromCamera(params);
      } else {
        ref = params.kind == MediaType.video
            ? await picker.pickVideo(params)
            : await picker.pickImage(params);
      }
      return Right(ref);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }
}
