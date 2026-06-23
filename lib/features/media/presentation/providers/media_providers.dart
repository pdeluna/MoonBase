import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:moonbase_skeleton/features/media/domain/entities/media_constraints.dart';
import 'package:moonbase_skeleton/features/media/domain/repositories/media_picker.dart';
import 'package:moonbase_skeleton/features/media/domain/repositories/media_storage.dart';
import 'package:moonbase_skeleton/features/media/domain/usecases/delete_media.dart';
import 'package:moonbase_skeleton/features/media/domain/usecases/pick_and_persist_media.dart';

/// Central caps for picked media (sizes, durations, fan-out per
/// message/post). Overridable in `ProviderScope` if a base ever needs custom
/// limits (e.g. a future per-base `BaseSettings.maxMediaBytes`).
final mediaConstraintsProvider = Provider<MediaConstraints>(
  (_) => MediaConstraints.defaults,
);

/// The single `MediaStorage` instance used by every feature that renders or
/// persists media. **Must** be overridden in `main.dart` with a concrete
/// implementation (Phase 3: `LocalFileMediaStorage`).
///
/// Widgets that need to turn a `MediaRef.storageKey` into a renderable URI
/// (`MediaTile`, `MediaPreview`, `VideoThumbnail`) read this provider
/// directly. This is the **only** sanctioned provider read inside a "dumb
/// tile" widget; see Phase 3 architectural constraint #3 in the DoD.
final mediaStorageProvider = Provider<MediaStorage>(
  (_) => throw UnimplementedError(
    'mediaStorageProvider must be overridden in main.dart with a concrete '
    'MediaStorage (Phase 3: LocalFileMediaStorage).',
  ),
);

/// The single `MediaPicker` instance. **Must** be overridden in `main.dart`
/// (Phase 3: `ImagePickerMediaPicker`).
final mediaPickerProvider = Provider<MediaPicker>(
  (_) => throw UnimplementedError(
    'mediaPickerProvider must be overridden in main.dart with a concrete '
    'MediaPicker (Phase 3: ImagePickerMediaPicker).',
  ),
);

/// Use cases — wired off the ports above so call sites depend on the
/// well-typed `Either<Failure, ...>` API, not on the picker / storage directly.
final pickAndPersistMediaUseCaseProvider = Provider<PickAndPersistMedia>(
  (ref) => PickAndPersistMedia(ref.read(mediaPickerProvider)),
);

final deleteMediaUseCaseProvider = Provider<DeleteMedia>(
  (ref) => DeleteMedia(ref.read(mediaStorageProvider)),
);
