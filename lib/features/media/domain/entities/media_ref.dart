import 'package:flutter/foundation.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/core/sync_status.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_type.dart';

/// A reference to a single piece of persisted media.
///
/// Phase 3 invariants:
///
/// - [storageKey] is a **content-addressable, base-scoped relative key**
///   (e.g. `<baseId>/<uuid>.<ext>`), never an absolute device path. The
///   `MediaStorage` port is responsible for resolving keys to a URI a Flutter
///   widget can load. This means files survive app reinstalls (the docs
///   directory path can change) and the cloud transition is mechanical.
/// - [syncStatus] defaults to [SyncStatus.synced] while the app is local-only.
///   A future Phase 4 outbox/sync service will create new local rows with
///   [SyncStatus.localOnly] and replay them.
///
/// See `docs/PHASE3_DOD_ACTION_LIST.md` §0.3.1.
@immutable
class MediaRef {
  const MediaRef({
    required this.id,
    required this.type,
    required this.storageKey,
    this.thumbnailKey,
    this.width,
    this.height,
    this.duration,
    this.sizeBytes,
    this.mimeType,
    this.syncStatus = SyncStatus.synced,
  });

  final MediaId id;
  final MediaType type;

  /// Opaque relative key understood by `MediaStorage`. Not a path.
  final String storageKey;

  /// Optional pre-rendered thumbnail key (e.g. for video first-frame).
  final String? thumbnailKey;

  final int? width;
  final int? height;

  /// Only meaningful for [MediaType.video].
  final Duration? duration;

  final int? sizeBytes;
  final String? mimeType;

  final SyncStatus syncStatus;

  MediaRef copyWith({
    MediaId? id,
    MediaType? type,
    String? storageKey,
    String? thumbnailKey,
    int? width,
    int? height,
    Duration? duration,
    int? sizeBytes,
    String? mimeType,
    SyncStatus? syncStatus,
  }) {
    return MediaRef(
      id: id ?? this.id,
      type: type ?? this.type,
      storageKey: storageKey ?? this.storageKey,
      thumbnailKey: thumbnailKey ?? this.thumbnailKey,
      width: width ?? this.width,
      height: height ?? this.height,
      duration: duration ?? this.duration,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      mimeType: mimeType ?? this.mimeType,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MediaRef &&
        other.id == id &&
        other.type == type &&
        other.storageKey == storageKey &&
        other.thumbnailKey == thumbnailKey &&
        other.width == width &&
        other.height == height &&
        other.duration == duration &&
        other.sizeBytes == sizeBytes &&
        other.mimeType == mimeType &&
        other.syncStatus == syncStatus;
  }

  @override
  int get hashCode => Object.hash(
        id,
        type,
        storageKey,
        thumbnailKey,
        width,
        height,
        duration,
        sizeBytes,
        mimeType,
        syncStatus,
      );

  @override
  String toString() =>
      'MediaRef(id: $id, type: $type, storageKey: $storageKey, syncStatus: $syncStatus)';
}
