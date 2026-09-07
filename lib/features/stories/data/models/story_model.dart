import 'package:moonbase_skeleton/core/sync_status.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';
import 'package:moonbase_skeleton/features/stories/domain/entities/story.dart';

/// JSON row. Wire shape: blueprint §4.8 (`ttlMs`, nested `media`).
///
/// Fill fromMap / toMap / toEntity. Missing keys default to
/// archived = false, syncStatus = synced, caption = null.
/// storageKey stays relative (`<baseId>/<uuid>.<ext>`), never a device path.
class StoryModel {
  const StoryModel({
    required this.id,
    required this.baseId,
    required this.authorUserId,
    required this.media,
    required this.ttlMs,
    required this.createdAt,
    this.caption,
    this.archived = false,
    this.syncStatus = SyncStatus.synced,
  });

  factory StoryModel.fromMap(Map<String, dynamic> map) {
    throw UnimplementedError('$map');
  }

  final String id;
  final String baseId;
  final String authorUserId;
  final MediaRef media;
  final String? caption;
  final int ttlMs;
  final DateTime createdAt;
  final bool archived;
  final SyncStatus syncStatus;

  Map<String, dynamic> toMap() {
    throw UnimplementedError('$id $baseId $ttlMs $archived $syncStatus');
  }

  Story toEntity() {
    throw UnimplementedError('$id $authorUserId $media $caption $createdAt');
  }
}
