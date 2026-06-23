import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/core/sync_status.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_type.dart';

/// Shared `Map<String, dynamic>` codec for `MediaRef`.
///
/// `MediaRef` is a pure domain entity — by Phase 3 architectural rule it
/// must not carry `toMap`/`fromMap`. Every data layer that persists media
/// (chat, stories, posts) needs the same serialization shape, so we
/// centralise it here in `lib/features/media/data/` rather than letting
/// each slice grow its own private copy.
///
/// Serialization invariants:
///
/// - `id`, `type`, and `syncStatus` are persisted as their `.value` /
///   `.name` (enum name). On read, unknown enum names fall back to the
///   defaults from the entity constructor (`SyncStatus.synced`).
/// - `duration` is persisted in **milliseconds** as `durationMs` so JSON
///   round-trips through `int` rather than ISO strings.
/// - Missing fields on read default to the same values the entity
///   constructor would produce, so legacy rows written before this codec
///   existed still deserialize.
///
/// See `docs/PHASE3_DOD_ACTION_LIST.md` Section 1.2.1.
class MediaRefCodec {
  const MediaRefCodec._();

  static Map<String, dynamic> toMap(MediaRef ref) => <String, dynamic>{
        'id': ref.id.value,
        'type': ref.type.name,
        'storageKey': ref.storageKey,
        if (ref.thumbnailKey != null) 'thumbnailKey': ref.thumbnailKey,
        if (ref.width != null) 'width': ref.width,
        if (ref.height != null) 'height': ref.height,
        if (ref.duration != null) 'durationMs': ref.duration!.inMilliseconds,
        if (ref.sizeBytes != null) 'sizeBytes': ref.sizeBytes,
        if (ref.mimeType != null) 'mimeType': ref.mimeType,
        'syncStatus': ref.syncStatus.name,
      };

  static MediaRef fromMap(Map<String, dynamic> map) {
    final durationMs = map['durationMs'];
    return MediaRef(
      id: MediaId(map['id'] as String),
      type: _mediaTypeOr(map['type'], MediaType.image),
      storageKey: map['storageKey'] as String,
      thumbnailKey: map['thumbnailKey'] as String?,
      width: map['width'] as int?,
      height: map['height'] as int?,
      duration: durationMs is int ? Duration(milliseconds: durationMs) : null,
      sizeBytes: map['sizeBytes'] as int?,
      mimeType: map['mimeType'] as String?,
      syncStatus: _syncStatusOr(map['syncStatus'], SyncStatus.synced),
    );
  }

  static List<Map<String, dynamic>> toMapList(List<MediaRef> refs) =>
      refs.map(toMap).toList(growable: false);

  static List<MediaRef> fromMapList(Iterable<dynamic>? raw) {
    if (raw == null) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(MediaRefCodec.fromMap)
        .toList(growable: false);
  }

  static MediaType _mediaTypeOr(Object? raw, MediaType fallback) {
    if (raw is! String) return fallback;
    for (final v in MediaType.values) {
      if (v.name == raw) return v;
    }
    return fallback;
  }

  static SyncStatus _syncStatusOr(Object? raw, SyncStatus fallback) {
    if (raw is! String) return fallback;
    for (final v in SyncStatus.values) {
      if (v.name == raw) return v;
    }
    return fallback;
  }
}
