import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/reactions/data/datasources/reaction_data_source.dart';
import 'package:moonbase_skeleton/features/reactions/data/models/reaction_batch.dart';
import 'package:moonbase_skeleton/features/reactions/data/models/reaction_model.dart';
import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction.dart';
import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction_kind.dart';
import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction_target.dart';

/// Cloud Firestore reactions — `bases/{baseId}/reactions/{id}` (R3).
///
/// Client cap on the listener so a very chatty base cannot pull an
/// unbounded set; the chat screen only joins against messages it renders.
const int kReactionListenerLimit = 500;

class ReactionFirestoreDataSource implements ReactionDataSource {
  ReactionFirestoreDataSource({
    FirebaseFirestore? firestore,
    fb.FirebaseAuth? auth,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? fb.FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final fb.FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> _col(String baseId) =>
      _db.collection('bases').doc(baseId).collection('reactions');

  void _assertSelf(String uid) {
    final authUid = _auth.currentUser?.uid;
    if (authUid == null || authUid != uid) {
      throw StateError('reactions require a signed-in user matching uid');
    }
  }

  @override
  Future<void> react({
    required String baseId,
    required ReactionTarget target,
    required String uid,
    required ReactionKind kind,
  }) async {
    _assertSelf(uid);
    final id = Reaction.idFor(target, uid.uid).value;
    final model = ReactionModel(
      id: id,
      targetKind: target.kind,
      targetId: target.id,
      uid: uid,
      kind: kind,
      createdAt: DateTime.now().toUtc(),
    );
    await _col(baseId).doc(id).set(model.toFirestore());
  }

  @override
  Future<void> unreact({
    required String baseId,
    required ReactionTarget target,
    required String uid,
  }) async {
    _assertSelf(uid);
    await _col(baseId).doc(Reaction.idFor(target, uid.uid).value).delete();
  }

  @override
  Stream<ReactionBatch> watchFor({
    required String baseId,
    required ReactionTargetKind targetKind,
  }) {
    // Requires composite index (targetKind ASC, createdAt DESC) — see
    // firestore.indexes.json. Until it is Enabled the SDK errors with
    // failed-precondition; the repository maps that to a typed Failure.
    // includeMetadataChanges: true so cache→live clears the banner (R5).
    return _col(baseId)
        .where('targetKind', isEqualTo: targetKind.name)
        .orderBy('createdAt', descending: true)
        .limit(kReactionListenerLimit)
        .snapshots(includeMetadataChanges: true)
        .map((snap) {
      final list = <ReactionModel>[];
      for (final d in snap.docs) {
        final m = ReactionModel.fromFirestore(d.id, d.data());
        if (m != null) list.add(m);
      }
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return ReactionBatch(
        reactions: list,
        fromCache: snap.metadata.isFromCache,
      );
    });
  }
}
