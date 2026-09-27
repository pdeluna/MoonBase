import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction.dart';
import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction_kind.dart';
import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction_target.dart';

/// Persistence DTO for `bases/{baseId}/reactions/{targetKind}:{targetId}:{uid}`.
///
/// Writes exactly `targetKind, targetId, uid, kind, createdAt
/// (serverTimestamp), schemaVersion: 1`. The doc id is `Reaction.idFor` —
/// never minted here, never stored as a field.
class ReactionModel {
  const ReactionModel({
    required this.id,
    required this.targetKind,
    required this.targetId,
    required this.uid,
    required this.kind,
    required this.createdAt,
  });

  static const firestoreSchemaVersion = 1;

  /// Null when the row cannot be represented (unknown kind / target kind
  /// written by a newer client, or a malformed body) — callers drop it.
  static ReactionModel? fromFirestore(String id, Map<String, dynamic> data) {
    final targetKind = ReactionTargetKind.tryParse(data['targetKind']);
    final kind = ReactionKind.tryParse(data['kind']);
    final targetId = data['targetId'];
    final uid = data['uid'];
    if (targetKind == null ||
        kind == null ||
        targetId is! String ||
        targetId.isEmpty ||
        uid is! String ||
        uid.isEmpty) {
      return null;
    }
    // Pending local writes have a null serverTimestamp; stand in with now
    // (UTC) so the newest-first sort keeps them at the newest end.
    final createdAt = switch (data['createdAt']) {
      Timestamp ts => ts.toDate().toUtc(),
      DateTime dt => dt.toUtc(),
      _ => DateTime.now().toUtc(),
    };
    return ReactionModel(
      id: id,
      targetKind: targetKind,
      targetId: targetId,
      uid: uid,
      kind: kind,
      createdAt: createdAt,
    );
  }

  final String id;
  final ReactionTargetKind targetKind;
  final String targetId;
  final String uid;
  final ReactionKind kind;
  final DateTime createdAt;

  Reaction toEntity() => Reaction(
        id: ReactionId(id),
        target: ReactionTarget(kind: targetKind, id: targetId),
        userId: uid.uid,
        kind: kind,
        createdAt: createdAt,
      );

  /// Write payload. `createdAt` is always the server clock so replacing a
  /// kind re-stamps the reaction (it is the listener's ordering field).
  Map<String, dynamic> toFirestore() => <String, dynamic>{
        'targetKind': targetKind.name,
        'targetId': targetId,
        'uid': uid,
        'kind': kind.name,
        'createdAt': FieldValue.serverTimestamp(),
        'schemaVersion': firestoreSchemaVersion,
      };
}
