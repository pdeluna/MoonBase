import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:moonbase_skeleton/features/bases/data/datasources/base_local_data_source.dart';
import 'package:moonbase_skeleton/features/bases/data/models/base_model.dart';
import 'package:moonbase_skeleton/features/bases/data/models/invite_model.dart';
import 'package:moonbase_skeleton/features/bases/data/models/member_model.dart';

/// SharedPreferences-backed base data source for persistence
/// Uses the same storage format as the legacy base system
class BaseSharedPrefsDataSource implements BaseLocalDataSource {
  BaseSharedPrefsDataSource(this._prefs);
  
  static const _kBases = 'mb.bases';
  static const _kMembersByBase = 'mb.membersByBase';
  static const _kBasesByUser = 'mb.basesByUser';
  static const _kInviteToBase = 'mb.inviteToBase';
  static const _kInvitesByBase = 'mb.invitesByBase';
  static const _kInvites = 'mb.invites';
  static const _kLastAccessedBasePrefix = 'mb.lastAccessedBase.';

  final SharedPreferences _prefs;

  // ---- helpers (per user) ----

  String? _getLastAccessedBase(String userId) {
    return _prefs.getString(_kLastAccessedBasePrefix + userId);
  }

  Future<void> _setLastAccessedBase(String userId, String baseId) async {
    await _prefs.setString(_kLastAccessedBasePrefix + userId, baseId);
  }

  Map<String, dynamic> _readBases() {
    final raw = _prefs.getString(_kBases);
    if (raw == null) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _writeBases(Map<String, dynamic> bases) async {
    await _prefs.setString(_kBases, jsonEncode(bases));
  }

  Map<String, dynamic> _readMembersByBase() {
    final raw = _prefs.getString(_kMembersByBase);
    if (raw == null) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _writeMembersByBase(Map<String, dynamic> membersByBase) async {
    await _prefs.setString(_kMembersByBase, jsonEncode(membersByBase));
  }

  Map<String, dynamic> _readBasesByUser() {
    final raw = _prefs.getString(_kBasesByUser);
    if (raw == null) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _writeBasesByUser(Map<String, dynamic> basesByUser) async {
    await _prefs.setString(_kBasesByUser, jsonEncode(basesByUser));
  }

  Map<String, dynamic> _readInviteToBase() {
    final raw = _prefs.getString(_kInviteToBase);
    if (raw == null) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _writeInviteToBase(Map<String, dynamic> inviteToBase) async {
    await _prefs.setString(_kInviteToBase, jsonEncode(inviteToBase));
  }

  Map<String, dynamic> _readInvitesByBase() {
    final raw = _prefs.getString(_kInvitesByBase);
    if (raw == null) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _writeInvitesByBase(Map<String, dynamic> invitesByBase) async {
    await _prefs.setString(_kInvitesByBase, jsonEncode(invitesByBase));
  }

  Map<String, dynamic> _readInvites() {
    final raw = _prefs.getString(_kInvites);
    if (raw == null) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _writeInvites(Map<String, dynamic> invites) async {
    await _prefs.setString(_kInvites, jsonEncode(invites));
  }

  String _genId() {
    return '${DateTime.now().toUtc().microsecondsSinceEpoch}_${DateTime.now().millisecondsSinceEpoch}';
  }

  String _genInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // avoid O/0/I/1
    final r = DateTime.now().millisecondsSinceEpoch;
    return List.generate(6, (i) => chars[(r + i) % chars.length]).join();
  }

  void _ensureUserIndex(String userId) {
    final basesByUser = _readBasesByUser();
    if (!basesByUser.containsKey(userId)) {
      basesByUser[userId] = <String>[];
      _writeBasesByUser(basesByUser);
    }
  }

  void _ensureBaseIndex(String baseId) {
    final membersByBase = _readMembersByBase();
    final invitesByBase = _readInvitesByBase();
    
    if (!membersByBase.containsKey(baseId)) {
      membersByBase[baseId] = <String>[];
      _writeMembersByBase(membersByBase);
    }
    
    if (!invitesByBase.containsKey(baseId)) {
      invitesByBase[baseId] = <String>[];
      _writeInvitesByBase(invitesByBase);
    }
  }

  // ---- BaseLocalDataSource implementation ----

  @override
  Future<List<BaseModel>> listBasesForUser(String userId) async {
    final basesByUser = _readBasesByUser();
    final bases = _readBases();
    
    final userBaseIds = List<String>.from((basesByUser[userId] as List<dynamic>?) ?? []);
    final userBases = <BaseModel>[];
    
    for (final baseId in userBaseIds) {
      final baseData = bases[baseId];
      if (baseData != null) {
        try {
          final base = BaseModel.fromMap(baseData as Map<String, dynamic>);
          userBases.add(base);
        } catch (_) {
          // Skip corrupted base data
        }
      }
    }
    
    userBases.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // newest first
    return userBases;
  }

  @override
  Future<List<MemberModel>> listMembersForBase(String baseId) async {
    final membersByBase = _readMembersByBase();
    final bases = _readBases();
    final raw = bases[baseId];
    final ownerUserId = raw is Map<String, dynamic>
        ? raw['ownerUserId'] as String?
        : null;
    final uids = List<String>.from(
      (membersByBase[baseId] as List<dynamic>?) ?? const <dynamic>[],
    );
    final joinedAt = DateTime.now().toUtc();
    return uids
        .map(
          (uid) => MemberModel(
            userId: uid,
            role: uid == ownerUserId ? 'owner' : 'member',
            nickname: uid,
            joinedAt: joinedAt,
          ),
        )
        .toList();
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

    // Save base
    final bases = _readBases();
    bases[id] = model.toMap();
    await _writeBases(bases);

    // Update indexes
    _ensureBaseIndex(id);
    _ensureUserIndex(ownerUserId);

    final membersByBase = _readMembersByBase();
    final basesByUser = _readBasesByUser();
    
    membersByBase[id] = [ownerUserId];
    basesByUser[ownerUserId] = [...(basesByUser[ownerUserId] as List<dynamic>? ?? []), id];
    
    await _writeMembersByBase(membersByBase);
    await _writeBasesByUser(basesByUser);

    return model;
  }

  @override
  Future<BaseModel> joinBase({
    required String inviteCode,
    required String userId,
  }) async {
    final code = inviteCode.toUpperCase().trim();
    final inviteToBase = _readInviteToBase();
    final baseId = inviteToBase[code] as String?;

    if (baseId == null) throw StateError('Invalid invite code');

    final bases = _readBases();
    final baseData = bases[baseId];
    if (baseData == null) throw StateError('Base no longer exists');

    final base = BaseModel.fromMap(baseData as Map<String, dynamic>);

    _ensureBaseIndex(baseId);
    _ensureUserIndex(userId);
    
    final membersByBase = _readMembersByBase();
    final basesByUser = _readBasesByUser();
    
    final baseMembers = membersByBase[baseId] as List<dynamic>? ?? [];
    if (!baseMembers.contains(userId)) {
      baseMembers.add(userId);
      membersByBase[baseId] = baseMembers;
      await _writeMembersByBase(membersByBase);
    }
    
    final userBases = basesByUser[userId] as List<dynamic>? ?? [];
    if (!userBases.contains(baseId)) {
      userBases.add(baseId);
      basesByUser[userId] = userBases;
      await _writeBasesByUser(basesByUser);
    }

    return base;
  }

  @override
  Future<void> leaveBase({
    required String baseId,
    required String userId,
  }) async {
    final membersByBase = _readMembersByBase();
    final basesByUser = _readBasesByUser();
    
    membersByBase[baseId]?.remove(userId);
    basesByUser[userId]?.remove(baseId);
    
    await _writeMembersByBase(membersByBase);
    await _writeBasesByUser(basesByUser);
    
    // Clean up empty sets
    if (basesByUser[userId]?.isEmpty == true) {
      basesByUser.remove(userId);
      await _writeBasesByUser(basesByUser);
    }
  }

  @override
  Future<void> renameBase({
    required String baseId,
    required String newName,
  }) async {
    final bases = _readBases();
    final baseData = bases[baseId];
    if (baseData == null) throw StateError('Base not found');
    
    final base = BaseModel.fromMap(baseData as Map<String, dynamic>);
    final updatedBase = BaseModel(
      id: base.id,
      name: newName,
      ownerUserId: base.ownerUserId,
      createdAt: base.createdAt,
    );
    
    bases[baseId] = updatedBase.toMap();
    await _writeBases(bases);
  }

  @override
  Future<void> deleteBase({required String baseId}) async {
    final bases = _readBases();
    final baseData = bases.remove(baseId);
    if (baseData == null) return;

    final membersByBase = _readMembersByBase();
    final basesByUser = _readBasesByUser();
    final invitesByBase = _readInvitesByBase();
    final inviteToBase = _readInviteToBase();
    final invites = _readInvites();

    // Remove from all indexes
    final members = List<String>.from((membersByBase.remove(baseId) as List<dynamic>?) ?? []);
    for (final userId in members) {
      final userBases = basesByUser[userId] as List<dynamic>?;
      if (userBases != null) {
        userBases.remove(baseId);
        if (userBases.isEmpty) {
          basesByUser.remove(userId);
        }
      }
    }

    // Clean up invites
    final baseInvites = List<String>.from((invitesByBase.remove(baseId) as List<dynamic>?) ?? []);
    for (final inviteId in baseInvites) {
      final inviteData = invites.remove(inviteId);
      if (inviteData != null) {
        final invite = InviteModel.fromMap(inviteData as Map<String, dynamic>);
        inviteToBase.remove(invite.code);
      }
    }

    await _writeBases(bases);
    await _writeMembersByBase(membersByBase);
    await _writeBasesByUser(basesByUser);
    await _writeInvitesByBase(invitesByBase);
    await _writeInviteToBase(inviteToBase);
    await _writeInvites(invites);
  }

  @override
  Future<String> generateInviteCode({
    required String baseId,
  }) async {
    final bases = _readBases();
    final baseData = bases[baseId];
    if (baseData == null) throw StateError('Base not found');

    final code = _genInviteCode();
    final invite = InviteModel(
      id: _genId(),
      baseId: baseId,
      code: code,
      createdByUserId: 'system', // Default since we don't have requesterUserId
      createdAt: DateTime.now().toUtc(),
      maxUses: null,
      expiresAt: null,
    );

    // Save invite
    final invites = _readInvites();
    invites[invite.id] = invite.toMap();
    await _writeInvites(invites);

    // Update indexes
    _ensureBaseIndex(baseId);
    final invitesByBase = _readInvitesByBase();
    final inviteToBase = _readInviteToBase();
    
    invitesByBase[baseId]!.add(invite.id);
    inviteToBase[code] = baseId;
    
    await _writeInvitesByBase(invitesByBase);
    await _writeInviteToBase(inviteToBase);

    return code;
  }

  @override
  Future<InviteModel> createInvite({
    required String baseId,
    required String createdByUserId,
    int? maxUses,
    DateTime? expiresAt,
  }) async {
    final bases = _readBases();
    final baseData = bases[baseId];
    if (baseData == null) throw StateError('Base not found');

    final code = _genInviteCode();
    final invite = InviteModel(
      id: _genId(),
      baseId: baseId,
      code: code,
      createdByUserId: createdByUserId,
      createdAt: DateTime.now().toUtc(),
      maxUses: maxUses,
      expiresAt: expiresAt,
    );

    // Save invite
    final invites = _readInvites();
    invites[invite.id] = invite.toMap();
    await _writeInvites(invites);

    // Update indexes
    _ensureBaseIndex(baseId);
    final invitesByBase = _readInvitesByBase();
    final inviteToBase = _readInviteToBase();
    
    invitesByBase[baseId]!.add(invite.id);
    inviteToBase[code] = baseId;
    
    await _writeInvitesByBase(invitesByBase);
    await _writeInviteToBase(inviteToBase);

    return invite;
  }

  @override
  Future<List<InviteModel>> listInvitesForBase(String baseId) async {
    final invitesByBase = _readInvitesByBase();
    final invites = _readInvites();
    
    final baseInviteIds = List<String>.from((invitesByBase[baseId] as List<dynamic>?) ?? []);
    final baseInvites = <InviteModel>[];
    
    for (final inviteId in baseInviteIds) {
      final inviteData = invites[inviteId];
      if (inviteData != null) {
        try {
          final invite = InviteModel.fromMap(inviteData as Map<String, dynamic>);
          baseInvites.add(invite);
        } catch (_) {
          // Skip corrupted invite data
        }
      }
    }
    
    return baseInvites;
  }

  @override
  Future<InviteModel?> getInviteByCode(String code) async {
    final lookup = code.toUpperCase().trim();
    final inviteToBase = _readInviteToBase();
    final baseId = inviteToBase[lookup] as String?;
    if (baseId == null) return null;

    final invitesByBase = _readInvitesByBase();
    final invites = _readInvites();

    final baseInviteIds =
        List<String>.from((invitesByBase[baseId] as List<dynamic>?) ?? []);
    for (final inviteId in baseInviteIds) {
      final inviteData = invites[inviteId];
      if (inviteData != null) {
        try {
          final invite = InviteModel.fromMap(inviteData as Map<String, dynamic>);
          if (invite.code == lookup) {
            return invite;
          }
        } catch (_) {
          // Skip corrupted invite data
        }
      }
    }
    
    return null;
  }

  @override
  Future<BaseModel?> getLastAccessedBase(String userId) async {
    final lastBaseId = _getLastAccessedBase(userId);
    if (lastBaseId == null) return null;

    final bases = _readBases();
    final baseData = bases[lastBaseId];
    if (baseData == null) return null;

    return BaseModel.fromMap(Map<String, dynamic>.from(baseData as Map));
  }

  @override
  Future<void> setLastAccessedBase(String userId, String baseId) async {
    await _setLastAccessedBase(userId, baseId);
  }
}
