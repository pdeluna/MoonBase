import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/error_mapper.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/usecase.dart';
import 'package:moonbase_skeleton/features/media/domain/repositories/media_storage.dart';

/// Removes a previously-persisted media blob from storage.
///
/// Best-effort: completes successfully even if the underlying object is
/// already gone. Failures only surface for unexpected I/O errors.
///
/// Called by:
/// - `DeleteStory` when archive is disabled (hard-delete on expiry).
/// - `DeletePost` (Slice C).
/// - `MessageComposer` when the user removes a staged attachment before
///   sending (Slice A).
///
/// See `docs/PHASE3_DOD_ACTION_LIST.md` §0.3.4.
class DeleteMedia implements UseCase<Unit, String> {
  const DeleteMedia(this.storage);

  final MediaStorage storage;

  @override
  Future<Either<Failure, Unit>> call(String storageKey) =>
      guard<Unit>(() async {
        await storage.delete(storageKey);
        return Unit.instance;
      });
}
