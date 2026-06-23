import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/usecase.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_pick_request.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_type.dart';
import 'package:moonbase_skeleton/features/media/domain/repositories/media_picker.dart';

/// Parameters for a gallery multi-image pick session.
class PickMultipleImagesParams {
  const PickMultipleImagesParams({
    required this.request,
    required this.limit,
  });

  final MediaPickRequest request;

  /// Maximum number of images the OS picker may return in one session.
  final int limit;
}

/// Picks up to [PickMultipleImagesParams.limit] gallery images in one OS
/// session, validates each, persists via `MediaStorage`, and returns all
/// resulting refs.
///
/// Cancellation (user backs out of the gallery) surfaces as `Right([])` —
/// not an error. Any validation failure on a selected file surfaces as
/// `Left(Failure)` for the whole batch (same as single-pick semantics).
class PickAndPersistMultipleImages
    implements UseCase<List<MediaRef>, PickMultipleImagesParams> {
  const PickAndPersistMultipleImages(this.picker);

  final MediaPicker picker;

  @override
  Future<Either<Failure, List<MediaRef>>> call(
    PickMultipleImagesParams params,
  ) async {
    assert(
      params.request.kind == MediaType.image,
      'multi-pick is gallery images only',
    );
    assert(params.request.source == MediaSource.gallery);
    assert(params.limit > 0);

    try {
      final refs = await picker.pickMultipleImages(
        params.request,
        limit: params.limit,
      );
      return Right(refs);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }
}
