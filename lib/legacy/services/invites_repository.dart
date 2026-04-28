import 'package:moonbase_skeleton/legacy/models/base_member.dart';
import 'package:moonbase_skeleton/legacy/models/invite.dart';
import 'package:moonbase_skeleton/legacy/models/enums.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'dart:math';

abstract class InvitesRepository {
  /// Create an invite for a base. Only the owner can create invites.
  /// Throws an exception if the user is not the owner of the base.
  Future<BaseInvite> createInvite({
    required String baseId, 
    required String userId, // The user creating the invite (must be owner)
    int? maxUses, 
    DateTime? expiresAt
  });
  
  /// Redeem an invite code. Validates expiration and usage limits,
  /// increments usedCount, and adds the user as a member with 'member' role.
  /// Throws an exception if the invite is invalid, expired, or depleted.
  Future<BaseMember> redeemInvite({required String code, required String userId});
  
  /// Get an invite by its code
  Future<BaseInvite?> getByCode(String code);
  
  /// Get all invites for a specific base
  Future<List<BaseInvite>> getByBaseId(String baseId);
}

/// SharedPreferences-backed repository for invites
/// Structure:
/// - mb.invites     : JSON object { inviteId : <BaseInvite JSON> }
/// - mb.inviteCodes : JSON object { code : inviteId }
class SpInvitesRepository implements InvitesRepository {
  static const _kInvites = 'mb.invites';
  static const _kInviteCodes = 'mb.inviteCodes';

  // ---- helpers ----

  Future<Map<String, dynamic>> _readInvites(SharedPreferences sp) async {
    final raw = sp.getString(_kInvites);
    if (raw == null) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _writeInvites(SharedPreferences sp, Map<String, dynamic> invites) async {
    await sp.setString(_kInvites, jsonEncode(invites));
  }

  Future<Map<String, dynamic>> _readInviteCodes(SharedPreferences sp) async {
    final raw = sp.getString(_kInviteCodes);
    if (raw == null) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _writeInviteCodes(SharedPreferences sp, Map<String, dynamic> inviteCodes) async {
    await sp.setString(_kInviteCodes, jsonEncode(inviteCodes));
  }

  // Generate a random 6-character code
  String _generateCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(6, (_) => chars.codeUnitAt(random.nextInt(chars.length)))
    );
  }

  // ---- InvitesRepository implementation ----

  @override
  Future<BaseInvite> createInvite({
    required String baseId, 
    required String userId,
    int? maxUses, 
    DateTime? expiresAt
  }) async {
    final sp = await SharedPreferences.getInstance();
    
    // Check if user is owner of the base
    // For now, we'll use a simplified check - in a real app, you'd use the bases repository
    final basesRaw = sp.getString('mb.bases');
    if (basesRaw != null) {
      try {
        final bases = jsonDecode(basesRaw) as Map<String, dynamic>;
        final baseJson = bases[baseId];
        if (baseJson != null) {
          final base = jsonDecode(baseJson as String) as Map<String, dynamic>;
          if (base['ownerUserId'] != userId) {
            throw Exception('Only base owner can create invites');
          }
        }
      } catch (_) {
        throw Exception('Base not found or invalid');
      }
    }

    final inviteId = const Uuid().v4();
    String code;
    Map<String, dynamic> inviteCodes;
    
    // Generate unique code
    do {
      code = _generateCode();
      inviteCodes = await _readInviteCodes(sp);
    } while (inviteCodes.containsKey(code));

    final now = DateTime.now();
    final invite = BaseInvite(
      id: inviteId,
      baseId: baseId,
      code: code,
      createdByUserId: userId,
      createdAt: now,
      expiresAt: expiresAt,
      maxUses: maxUses,
      usedCount: 0,
    );

    // Save invite
    final invites = await _readInvites(sp);
    invites[inviteId] = invite.toMap();
    await _writeInvites(sp, invites);

    // Save code mapping
    inviteCodes[code] = inviteId;
    await _writeInviteCodes(sp, inviteCodes);

    return invite;
  }

  @override
  Future<BaseMember> redeemInvite({required String code, required String userId}) async {
    final sp = await SharedPreferences.getInstance();
    
    // Get invite by code
    final invite = await getByCode(code);
    if (invite == null) {
      throw Exception('Invalid invite code');
    }

    // Check if invite is expired
    if (invite.isExpired) {
      throw Exception('Invite has expired');
    }

    // Check if invite is depleted
    if (invite.isDepleted) {
      throw Exception('Invite has reached maximum uses');
    }

    // Check if user is already a member
    final existingMembers = await _readMembers(sp);
    final existingBaseMembers = existingMembers[invite.baseId] as List<dynamic>? ?? <dynamic>[];
    for (final existingMember in existingBaseMembers) {
      if (existingMember is Map<String, dynamic> && existingMember['userId'] == userId) {
        throw Exception('User is already a member of this base');
      }
    }

    // Increment used count
    final invites = await _readInvites(sp);
    final inviteJson = invites[invite.id];
    if (inviteJson != null) {
      final updatedInvite = BaseInvite.fromMap(inviteJson as Map<String, dynamic>);
      final newInvite = BaseInvite(
        id: updatedInvite.id,
        baseId: updatedInvite.baseId,
        code: updatedInvite.code,
        createdByUserId: updatedInvite.createdByUserId,
        createdAt: updatedInvite.createdAt,
        expiresAt: updatedInvite.expiresAt,
        maxUses: updatedInvite.maxUses,
        usedCount: updatedInvite.usedCount + 1,
      );
      invites[invite.id] = newInvite.toMap();
      await _writeInvites(sp, invites);
    }

    // Add user as member
    final now = DateTime.now();
    final member = BaseMember(
      id: const Uuid().v4(),
      baseId: invite.baseId,
      userId: userId,
      role: BaseRole.member,
      joinedAt: now,
      updatedAt: now,
    );

    // Save member
    final members = await _readMembers(sp);
    final baseMembers = List<Map<String, dynamic>>.from((members[invite.baseId] ?? <Map<String, dynamic>>[]) as Iterable<dynamic>);
    baseMembers.add(member.toMap());
    members[invite.baseId] = baseMembers;
    await _writeMembers(sp, members);

    // Add to user's bases
    final userBases = await _readUserBases(sp);
    final userBaseList = List<String>.from((userBases[userId] ?? <String>[]) as Iterable<dynamic>);
    if (!userBaseList.contains(invite.baseId)) {
      userBaseList.add(invite.baseId);
      userBases[userId] = userBaseList;
      await _writeUserBases(sp, userBases);
    }

    return member;
  }

  @override
  Future<BaseInvite?> getByCode(String code) async {
    final sp = await SharedPreferences.getInstance();
    final inviteCodes = await _readInviteCodes(sp);
    final inviteId = inviteCodes[code];
    
    if (inviteId == null) return null;

    final invites = await _readInvites(sp);
    final inviteJson = invites[inviteId];
    if (inviteJson == null) return null;

    try {
      return BaseInvite.fromMap(inviteJson as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<BaseInvite>> getByBaseId(String baseId) async {
    final sp = await SharedPreferences.getInstance();
    final invites = await _readInvites(sp);
    return invites.values
        .whereType<Map<String, dynamic>>()
        .map((json) => BaseInvite.fromMap(json))
        .where((invite) => invite.baseId == baseId)
        .toList();
  }

  // Helper methods (copied from SpBasesRepository for simplicity)
  Future<Map<String, dynamic>> _readMembers(SharedPreferences sp) async {
    final raw = sp.getString('mb.members');
    if (raw == null) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _writeMembers(SharedPreferences sp, Map<String, dynamic> members) async {
    await sp.setString('mb.members', jsonEncode(members));
  }

  Future<Map<String, dynamic>> _readUserBases(SharedPreferences sp) async {
    final raw = sp.getString('mb.userBases');
    if (raw == null) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _writeUserBases(SharedPreferences sp, Map<String, dynamic> userBases) async {
    await sp.setString('mb.userBases', jsonEncode(userBases));
  }
}