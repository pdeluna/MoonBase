import 'dart:async';

import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/reactions/data/datasources/reaction_data_source.dart';
import 'package:moonbase_skeleton/features/reactions/data/models/reaction_batch.dart';
import 'package:moonbase_skeleton/features/reactions/data/models/reaction_model.dart';
import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction.dart';
import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction_kind.dart';
import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction_target.dart';

/// DEV/TEST-ONLY in-memory reactions; resets on hot restart. Same id
/// discipline as Firestore (deterministic id ⇒ upsert/delete).
class InMemoryReactionDataSource implements ReactionDataSource {
  final Map<String, Map<String, ReactionModel>> _byBase = {};
  final Map<String, StreamController<ReactionBatch>> _controllers = {};

  DateTime Function() now = () => DateTime.now().toUtc();

  Map<String, ReactionModel> _rows(String baseId) =>
      _byBase.putIfAbsent(baseId, () => <String, ReactionModel>{});

  ReactionBatch _batch(String baseId, ReactionTargetKind kind) {
    final list = _rows(baseId)
        .values
        .where((r) => r.targetKind == kind)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return ReactionBatch(reactions: list, fromCache: false);
  }

  String _key(String baseId, ReactionTargetKind kind) => '$baseId/${kind.name}';

  void _emit(String baseId) {
    for (final kind in ReactionTargetKind.values) {
      final c = _controllers[_key(baseId, kind)];
      if (c != null && !c.isClosed) c.add(_batch(baseId, kind));
    }
  }

  @override
  Future<void> react({
    required String baseId,
    required ReactionTarget target,
    required String uid,
    required ReactionKind kind,
  }) async {
    final id = Reaction.idFor(target, uid.uid).value;
    _rows(baseId)[id] = ReactionModel(
      id: id,
      targetKind: target.kind,
      targetId: target.id,
      uid: uid,
      kind: kind,
      createdAt: now(),
    );
    _emit(baseId);
  }

  @override
  Future<void> unreact({
    required String baseId,
    required ReactionTarget target,
    required String uid,
  }) async {
    _rows(baseId).remove(Reaction.idFor(target, uid.uid).value);
    _emit(baseId);
  }

  @override
  Stream<ReactionBatch> watchFor({
    required String baseId,
    required ReactionTargetKind targetKind,
  }) {
    final key = _key(baseId, targetKind);
    return _controllers
        .putIfAbsent(
          key,
          () => StreamController<ReactionBatch>.broadcast(
            onListen: () => _controllers[key]!.add(_batch(baseId, targetKind)),
          ),
        )
        .stream;
  }
}
