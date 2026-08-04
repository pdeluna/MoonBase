import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:uuid/uuid.dart';

import 'package:moonbase_skeleton/features/chat/data/datasources/chat_local_data_source.dart';
import 'package:moonbase_skeleton/features/chat/data/models/message_model.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';

/// Cloud Firestore chat — `bases/{baseId}/messages/{messageId}`.
///
/// Writes exactly `authorUid`, `text`, `createdAt` (serverTimestamp),
/// `schemaVersion: 1`. Message ids are client-generated ([Uuid]) so a later
/// optimistic-send pass can dedup without changing the write path.
///
/// The stream is `orderBy('createdAt').snapshots()`. After mapping, the list
/// is always re-sorted by `createdAt` so pending null→`now()` stand-ins land
/// at the newest end (query order alone puts nulls first / oldest).
class ChatFirestoreDataSource implements ChatLocalDataSource {
  ChatFirestoreDataSource({
    FirebaseFirestore? firestore,
    fb.FirebaseAuth? auth,
    Uuid? uuid,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? fb.FirebaseAuth.instance,
        _uuid = uuid ?? const Uuid();

  final FirebaseFirestore _db;
  final fb.FirebaseAuth _auth;
  final Uuid _uuid;

  CollectionReference<Map<String, dynamic>> _messagesCol(String baseId) =>
      _db.collection('bases').doc(baseId).collection('messages');

  @override
  Future<MessageModel> sendMessage({
    required String baseId,
    required String userId,
    required String content,
    List<MediaRef> media = const [],
  }) async {
    final authUid = _auth.currentUser?.uid;
    if (authUid == null || authUid != userId) {
      throw StateError(
        'sendMessage requires a signed-in user matching userId',
      );
    }

    final messageId = _uuid.v4();
    final now = DateTime.now().toUtc();
    final model = MessageModel(
      id: messageId,
      baseId: baseId,
      userId: userId,
      content: content,
      createdAt: now,
      media: List<MediaRef>.unmodifiable(media),
    );

    await _messagesCol(baseId).doc(messageId).set(model.toFirestore());
    return model;
  }

  @override
  Stream<List<MessageModel>> streamMessages(String baseId) {
    return _messagesCol(baseId).orderBy('createdAt').snapshots().map((snap) {
      final list = snap.docs
          .map((d) => MessageModel.fromFirestore(d.id, baseId, d.data()))
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return list;
    });
  }

  @override
  Future<List<MessageModel>> listMessages({
    required String baseId,
    DateTime? before,
    int limit = 50,
  }) async {
    Query<Map<String, dynamic>> query = _messagesCol(baseId);
    if (before != null) {
      query = query.where(
        'createdAt',
        isLessThan: Timestamp.fromDate(before.toUtc()),
      );
    }
    query = query.orderBy('createdAt', descending: true).limit(limit);

    final snap = await query.get();
    final list = snap.docs
        .map((d) => MessageModel.fromFirestore(d.id, baseId, d.data()))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }
}
