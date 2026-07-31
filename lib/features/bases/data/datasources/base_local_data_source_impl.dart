import 'dart:math';

import 'package:moonbase_skeleton/features/bases/data/datasources/base_local_data_source.dart';
import 'package:moonbase_skeleton/features/bases/data/models/base_model.dart';
import 'package:moonbase_skeleton/features/bases/data/models/invite_model.dart';
import 'package:moonbase_skeleton/features/bases/data/models/member_model.dart';

/// DEV-ONLY: In-memory store (no persistence). Resets on hot restart.
class InMemoryBaseLocalDataSource implements BaseLocalDataSource {
  final Map<String, BaseModel> _bases = {};
  final Map<String, Set<String>> _membersByBase = {};
  final Map<String, Set<String>> _basesByUser = {};
  final Map<String, String> _inviteToBase = {};
  final Map<String, Set<String>> _invitesByBase = {};
  final Map<String, InviteModel> _invites = {};

  String _genId() {
    final r = Random();
    return '${DateTime.now().toUtc().microsecondsSinceEpoch}_${r.nextInt(1 << 32)}';
    // swap to your core/uuid later if preferred
  }

  String _genInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // avoid O/0/I/1
    final r = Random.secure();
    return List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
  }

  void _ensureUserIndex(String userId) {
    _basesByUser.putIfAbsent(userId, () => <String>{});
  }

  void _ensureBaseIndex(String baseId) {
    _membersByBase.putIfAbsent(baseId, () => <String>{});
    _invitesByBase.putIfAbsent(baseId, () => <String>{});
  }

  @override
  Future<List<BaseModel>> listBasesForUser(String userId) async {
    final ids = _basesByUser[userId];
    if (ids == null) return [];
    final list = ids.map((id) => _bases[id]).whereType<BaseModel>().toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // newest first
    return list;
  }

  @override
  Future<BaseModel> createBase({
    required String name,
    required String ownerUserId,
  }) async {
    final id = _genId();
    final model = BaseModel(
      id: id,
      name: name,
      ownerUserId: ownerUserId,
      createdAt: DateTime.now().toUtc(),
    );

    _bases[id] = model;
    _ensureBaseIndex(id);
    _ensureUserIndex(ownerUserId);

    _membersByBase[id]!.add(ownerUserId);
    _basesByUser[ownerUserId]!.add(id);

    return model;
  }

  @override
  Future<List<MemberModel>> listMembersForBase(String baseId) async {
    final ids = _membersByBase[baseId];
    if (ids == null) return [];
    final joinedAt = DateTime.now().toUtc();
    return ids
        .map(
          (uid) => MemberModel(
            userId: uid,
            role: _bases[baseId]?.ownerUserId == uid ? 'owner' : 'member',
            nickname: uid,
            joinedAt: joinedAt,
          ),
        )
        .toList();
  }

  @override
  Future<BaseModel> joinBase({
    required String inviteCode,
    required String userId,
  }) async {
    final code = inviteCode.toUpperCase().trim();
    final baseId = _inviteToBase[code];
    if (baseId == null) throw StateError('Invalid invite code');

    final base = _bases[baseId];
    if (base == null) throw StateError('Base no longer exists');

    _ensureBaseIndex(baseId);
    _ensureUserIndex(userId);
    _membersByBase[baseId]!.add(userId);
    _basesByUser[userId]!.add(baseId);

    return base;
  }

  @override
  Future<void> leaveBase({
    required String baseId,
    required String userId,
  }) async {
    _membersByBase[baseId]?.remove(userId);
    _basesByUser[userId]?.remove(baseId);
    
    // Clean up empty sets
    if (_basesByUser[userId]?.isEmpty == true) {
      _basesByUser.remove(userId);
    }
  }

  @override
  Future<void> renameBase({
    required String baseId,
    required String newName,
  }) async {
    final base = _bases[baseId];
    if (base == null) throw StateError('Base not found');
    _bases[baseId] = BaseModel(
      id: base.id,
      name: newName,
      ownerUserId: base.ownerUserId,
      createdAt: base.createdAt,
    );
  }

  @override
  Future<void> deleteBase({required String baseId}) async {
    final base = _bases.remove(baseId);
    if (base == null) return;

    final members = _membersByBase.remove(baseId) ?? {};
    for (final userId in members) {
      final set = _basesByUser[userId];
      set?.remove(baseId);
      if (set != null && set.isEmpty) _basesByUser.remove(userId);
    }

    final codes = _invitesByBase.remove(baseId) ?? {};
    for (final c in codes) {
      _inviteToBase.remove(c);
    }
  }

  @override
  Future<String> generateInviteCode({required String baseId}) async {
    if (!_bases.containsKey(baseId)) throw StateError('Base not found');
    _ensureBaseIndex(baseId);

    String code;
    int guard = 0;
    do {
      code = _genInviteCode();
      guard++;
      if (guard > 20) throw StateError('Could not generate invite code');
    } while (_inviteToBase.containsKey(code));

    _inviteToBase[code] = baseId;
    _invitesByBase[baseId]!.add(code);
    return code;
  }

  @override
  Future<InviteModel> createInvite({
    required String baseId,
    required String createdByUserId,
    int? maxUses,
    DateTime? expiresAt,
  }) async {
    if (!_bases.containsKey(baseId)) {
      throw StateError('Base not found');
    }
    _ensureBaseIndex(baseId);

    final id = _genId();
    final code = await generateInviteCode(baseId: baseId);
    
    final invite = InviteModel(
      id: id,
      baseId: baseId,
      code: code,
      createdByUserId: createdByUserId,
      createdAt: DateTime.now(),
      expiresAt: expiresAt,
      maxUses: maxUses,
      usedCount: 0,
    );

    _invites[id] = invite;
    return invite;
  }

  @override
  Future<List<InviteModel>> listInvitesForBase(String baseId) async {
    return _invites.values
        .where((invite) => invite.baseId == baseId)
        .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<InviteModel?> getInviteByCode(String code) async {
    final lookup = code.toUpperCase().trim();
    try {
      return _invites.values.firstWhere((invite) => invite.code == lookup);
    } catch (e) {
      return null; // Invite not found
    }
  }

  @override
  Future<BaseModel?> getLastAccessedBase(String userId) async {
    return null;
  }

  @override
  Future<void> setLastAccessedBase(String userId, String baseId) async {
    // No-op for dev environment
  }
}
