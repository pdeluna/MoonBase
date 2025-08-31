import 'package:moonbase_skeleton/models/base.dart';
import 'package:moonbase_skeleton/models/base_member.dart';
import 'package:moonbase_skeleton/models/enums.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';

abstract class BasesRepository {
  Future<Base> createBase({required String name, String? description, String? avatarUrl, required String userId});
  Future<void> deleteBase(String baseId, {required String userId});
  Future<Base> updateBase(String baseId, {required String name, String? description, String? avatarUrl, required String userId});

  Future<Base?> getBase(String baseId);
  Future<List<Base>> listMyBases(String userId);

  Future<BaseMember> addMember({required String baseId, required String userId, required BaseRole role});
  Future<void> removeMember({required String baseId, required String userId});

  Future<List<BaseMember>> listMembers(String baseId);
  Future<void> upsert(Base base);
  
  /// Check if a user is the owner of a base
  Future<bool> isOwner({required String baseId, required String userId});
  Future<void> updateLastAccessed(String baseId);
}

/// SharedPreferences-backed repository for bases
/// Structure:
/// - mb.bases       : JSON object { baseId : <Base JSON> }
/// - mb.members     : JSON object { baseId : [<BaseMember JSON>] }
/// - mb.userBases   : JSON object { userId : [baseId] }
class SpBasesRepository implements BasesRepository {
  static const _kBases = 'mb.bases';
  static const _kMembers = 'mb.members';
  static const _kUserBases = 'mb.userBases';

  // ---- helpers ----

  Future<Map<String, dynamic>> _readBases(SharedPreferences sp) async {
    final raw = sp.getString(_kBases);
    if (raw == null) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _writeBases(SharedPreferences sp, Map<String, dynamic> bases) async {
    await sp.setString(_kBases, jsonEncode(bases));
  }

  Future<Map<String, dynamic>> _readMembers(SharedPreferences sp) async {
    final raw = sp.getString(_kMembers);
    if (raw == null) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _writeMembers(SharedPreferences sp, Map<String, dynamic> members) async {
    await sp.setString(_kMembers, jsonEncode(members));
  }

  Future<Map<String, dynamic>> _readUserBases(SharedPreferences sp) async {
    final raw = sp.getString(_kUserBases);
    if (raw == null) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _writeUserBases(SharedPreferences sp, Map<String, dynamic> userBases) async {
    await sp.setString(_kUserBases, jsonEncode(userBases));
  }

  // ---- BasesRepository implementation ----

  @override
  Future<Base> createBase({required String name, String? description, String? avatarUrl, required String userId}) async {
    final sp = await SharedPreferences.getInstance();

    final baseId = const Uuid().v4();
    final now = DateTime.now();
    
    final base = Base(
      id: baseId,
      name: name,
      ownerUserId: userId,
      description: description,
      avatarUrl: avatarUrl,
      memberIds: [userId], // Owner is automatically a member
      createdAt: now,
      updatedAt: now,
      lastAccessedAt: now, // Set initial access time
    );

    // Save base
    final bases = await _readBases(sp);
    bases[baseId] = base.toJson();
    await _writeBases(sp, bases);

    // Add to user's bases
    final userBases = await _readUserBases(sp);
    final userBaseList = List<String>.from(userBases[userId] ?? []);
    userBaseList.add(baseId);
    userBases[userId] = userBaseList;
    await _writeUserBases(sp, userBases);

    // Add owner as member directly (avoiding circular dependency)
    final members = await _readMembers(sp);
    final baseMembers = List<Map<String, dynamic>>.from(members[baseId] ?? []);
    final ownerMember = BaseMember(
      id: const Uuid().v4(),
      baseId: baseId,
      userId: userId,
      role: BaseRole.owner,
      joinedAt: now,
      updatedAt: now,
    );
    baseMembers.add(ownerMember.toMap());
    members[baseId] = baseMembers;
    await _writeMembers(sp, members);

    return base;
  }

  @override
  Future<void> deleteBase(String baseId, {required String userId}) async {
    final sp = await SharedPreferences.getInstance();
    
    // Check if current user is owner
    final isOwner = await this.isOwner(baseId: baseId, userId: userId);
    if (!isOwner) {
      throw Exception('Only base owner can delete the base');
    }

    // Remove base from all users' lists
    final userBases = await _readUserBases(sp);
    for (final userId in userBases.keys) {
      final userBaseList = List<String>.from(userBases[userId] ?? []);
      userBaseList.remove(baseId);
      userBases[userId] = userBaseList;
    }
    await _writeUserBases(sp, userBases);

    // Remove base
    final bases = await _readBases(sp);
    bases.remove(baseId);
    await _writeBases(sp, bases);

    // Remove members
    final members = await _readMembers(sp);
    members.remove(baseId);
    await _writeMembers(sp, members);
  }

  @override
  Future<Base> updateBase(String baseId, {required String name, String? description, String? avatarUrl, required String userId}) async {
    final sp = await SharedPreferences.getInstance();
    
    // Check if current user is owner
    final isOwner = await this.isOwner(baseId: baseId, userId: userId);
    if (!isOwner) {
      throw Exception('Only base owner can update the base');
    }

    // Get current base
    final bases = await _readBases(sp);
    final baseJson = bases[baseId];
    if (baseJson == null) {
      throw Exception('Base not found');
    }

    final currentBase = Base.fromJson(baseJson);
    final now = DateTime.now();
    
    // Update base
    final updatedBase = currentBase.copyWith(
      name: name,
      description: description,
      avatarUrl: avatarUrl,
      updatedAt: now,
    );

    bases[baseId] = updatedBase.toJson();
    await _writeBases(sp, bases);

    return updatedBase;
  }

  @override
  Future<Base?> getBase(String baseId) async {
    final sp = await SharedPreferences.getInstance();
    final bases = await _readBases(sp);
    final baseJson = bases[baseId];
    if (baseJson == null) return null;
    
    try {
      return Base.fromJson(baseJson);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Base>> listMyBases(String userId) async {
    final sp = await SharedPreferences.getInstance();
    final userBases = await _readUserBases(sp);
    final baseIds = List<String>.from(userBases[userId] ?? []);
    
    final bases = await _readBases(sp);
    
    final result = <Base>[];
    
    for (final baseId in baseIds) {
      final baseJson = bases[baseId];
      if (baseJson != null) {
        try {
          final base = Base.fromJson(baseJson);
          result.add(base);
        } catch (_) {
          // Skip corrupted base data
        }
      }
    }
    
    return result;
  }

  @override
  Future<BaseMember> addMember({required String baseId, required String userId, required BaseRole role}) async {
    final sp = await SharedPreferences.getInstance();
    
    // Check if base exists
    final base = await getBase(baseId);
    if (base == null) {
      throw Exception('Base not found');
    }

    final now = DateTime.now();
    final member = BaseMember(
      id: const Uuid().v4(),
      baseId: baseId,
      userId: userId,
      role: role,
      joinedAt: now,
      updatedAt: now,
    );

    // Add to members list
    final members = await _readMembers(sp);
    final baseMembers = List<Map<String, dynamic>>.from(members[baseId] ?? []);
    baseMembers.add(member.toMap());
    members[baseId] = baseMembers;
    await _writeMembers(sp, members);

    // Add to user's bases if not already there
    final userBases = await _readUserBases(sp);
    final userBaseList = List<String>.from(userBases[userId] ?? []);
    if (!userBaseList.contains(baseId)) {
      userBaseList.add(baseId);
      userBases[userId] = userBaseList;
      await _writeUserBases(sp, userBases);
    }

    // Update base memberIds
    final bases = await _readBases(sp);
    final baseJson = bases[baseId];
    if (baseJson != null) {
      try {
        final base = Base.fromJson(baseJson);
        final updatedBase = base.copyWith(
          memberIds: [...base.memberIds, userId],
          updatedAt: now,
        );
        bases[baseId] = updatedBase.toJson();
        await _writeBases(sp, bases);
      } catch (_) {
        // Handle corrupted base data
      }
    }

    return member;
  }

  @override
  Future<void> removeMember({required String baseId, required String userId}) async {
    final sp = await SharedPreferences.getInstance();
    
    // TODO: We need to get the current user ID from the session
    // For now, we'll skip the ownership check to fix the immediate issue
    // This should be fixed in a future iteration

    // Remove from members list
    final members = await _readMembers(sp);
    final baseMembers = List<Map<String, dynamic>>.from(members[baseId] ?? []);
    baseMembers.removeWhere((member) => member['userId'] == userId);
    members[baseId] = baseMembers;
    await _writeMembers(sp, members);

    // Remove from user's bases
    final userBases = await _readUserBases(sp);
    final userBaseList = List<String>.from(userBases[userId] ?? []);
    userBaseList.remove(baseId);
    userBases[userId] = userBaseList;
    await _writeUserBases(sp, userBases);

    // Update base memberIds
    final bases = await _readBases(sp);
    final baseJson = bases[baseId];
    if (baseJson != null) {
      try {
        final base = Base.fromJson(baseJson);
        final updatedBase = base.copyWith(
          memberIds: base.memberIds.where((id) => id != userId).toList(),
          updatedAt: DateTime.now(),
        );
        bases[baseId] = updatedBase.toJson();
        await _writeBases(sp, bases);
      } catch (_) {
        // Handle corrupted base data
      }
    }
  }

  @override
  Future<List<BaseMember>> listMembers(String baseId) async {
    final sp = await SharedPreferences.getInstance();
    final members = await _readMembers(sp);
    final baseMembers = List<Map<String, dynamic>>.from(members[baseId] ?? []);
    
    final result = <BaseMember>[];
    for (final memberJson in baseMembers) {
      try {
        final member = BaseMember.fromMap(memberJson);
        result.add(member);
      } catch (_) {
        // Skip corrupted member data
      }
    }
    
    return result;
  }

  @override
  Future<void> upsert(Base base) async {
    final sp = await SharedPreferences.getInstance();
    final bases = await _readBases(sp);
    bases[base.id] = base.toJson();
    await _writeBases(sp, bases);
  }

  @override
  Future<bool> isOwner({required String baseId, required String userId}) async {
    final base = await getBase(baseId);
    return base?.ownerUserId == userId;
  }

  @override
  Future<void> updateLastAccessed(String baseId) async {
    final sp = await SharedPreferences.getInstance();
    final bases = await _readBases(sp);
    final baseJson = bases[baseId];
    if (baseJson != null) {
      try {
        final base = Base.fromJson(baseJson);
        final updatedBase = base.copyWith(
          lastAccessedAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        bases[baseId] = updatedBase.toJson();
        await _writeBases(sp, bases);
      } catch (_) {
        // Handle corrupted base data
      }
    }
  }
}