import 'package:flutter/foundation.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_constraints.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_type.dart';

/// Where the picker should look for the media.
///
/// `gallery` opens the OS photo library; `camera` opens the OS camera
/// (`image_picker` with `ImageSource.camera`). A future custom in-app camera
/// surface is a Phase 4 alternative implementation of `MediaPicker`; either
/// way the source contract is the same.
enum MediaSource {
  gallery,
  camera,
}

/// A single request handed to a `MediaPicker` implementation. The same shape
/// is consumed by `pickImage`, `pickVideo`, and `captureFromCamera`.
///
/// See `docs/PHASE3_DOD_ACTION_LIST.md` §0.3.1.
@immutable
class MediaPickRequest {
  const MediaPickRequest({
    required this.baseId,
    required this.kind,
    required this.source,
    this.maxBytes,
    this.maxDuration,
  });

  /// All persisted media is base-scoped from the moment it is captured.
  /// Pickers must include this in the resulting `MediaRef.storageKey`.
  final BaseId baseId;

  final MediaType kind;
  final MediaSource source;

  /// Byte cap; null means use [MediaConstraints.imageMaxBytes] or
  /// [MediaConstraints.videoMaxBytes] depending on [kind].
  final int? maxBytes;

  /// Duration cap (videos only); null means use
  /// [MediaConstraints.videoMaxDuration].
  final Duration? maxDuration;

  /// Resolves [maxBytes] against the supplied [constraints].
  int effectiveMaxBytes(MediaConstraints constraints) =>
      maxBytes ??
      (kind == MediaType.video
          ? constraints.videoMaxBytes
          : constraints.imageMaxBytes);

  /// Resolves [maxDuration] against the supplied [constraints]. Only meaningful
  /// when [kind] is [MediaType.video].
  Duration effectiveMaxDuration(MediaConstraints constraints) =>
      maxDuration ?? constraints.videoMaxDuration;
}
