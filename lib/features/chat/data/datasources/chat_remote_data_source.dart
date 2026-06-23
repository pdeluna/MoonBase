import 'package:moonbase_skeleton/features/chat/data/models/message_model.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';

/// Placeholder for future backend.
///
/// Phase 3 (Slice A) mirrors the local-data-source `media` parameter for
/// signature symmetry. Phase 4's cloud implementation will additionally
/// upload media bytes via a server-side `MediaStorage` before persisting
/// the message row.
abstract class ChatRemoteDataSource {
  Future<MessageModel> sendMessage({
    required String baseId,
    required String userId,
    required String content,
    List<MediaRef> media = const [],
  });

  Stream<List<MessageModel>> streamMessages(String baseId);

  Future<List<MessageModel>> listMessages({
    required String baseId,
    DateTime? before,
    int limit = 50,
  });
}
