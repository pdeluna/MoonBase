import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/core/sync_status.dart';
import 'package:moonbase_skeleton/features/chat/domain/entities/message.dart';
import 'package:moonbase_skeleton/features/media/data/models/media_ref_codec.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';

/// Persistence DTO for `Message`.
///
/// Phase 3 (Slice A) adds `media` + `syncStatus`. Both have safe defaults
/// in `fromMap` so rows written by the Phase 2 schema continue to
/// deserialize:
///
/// - missing `media` field → `const []`
/// - missing `syncStatus` field → `SyncStatus.synced`
///
/// See `docs/PHASE3_DOD_ACTION_LIST.md` Section 1.2.1.
class MessageModel {
  const MessageModel({
    required this.id,
    required this.baseId,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.media = const [],
    this.syncStatus = SyncStatus.synced,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map) => MessageModel(
        id: map['id'] as String,
        baseId: map['baseId'] as String,
        userId: map['userId'] as String,
        content: map['content'] as String,
        createdAt: DateTime.parse(map['createdAt'] as String),
        media: MediaRefCodec.fromMapList(map['media'] as Iterable<dynamic>?),
        syncStatus: _syncStatusOr(map['syncStatus'], SyncStatus.synced),
      );

  final String id;
  final String baseId;
  final String userId;
  final String content;
  final DateTime createdAt;
  final List<MediaRef> media;
  final SyncStatus syncStatus;

  Message toEntity() => Message(
        id: id.mid,
        baseId: baseId.bid,
        userId: userId.uid,
        content: content,
        createdAt: createdAt,
        media: media,
        syncStatus: syncStatus,
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'baseId': baseId,
        'userId': userId,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        if (media.isNotEmpty) 'media': MediaRefCodec.toMapList(media),
        'syncStatus': syncStatus.name,
      };
}

SyncStatus _syncStatusOr(Object? raw, SyncStatus fallback) {
  if (raw is! String) return fallback;
  for (final v in SyncStatus.values) {
    if (v.name == raw) return v;
  }
  return fallback;
}
