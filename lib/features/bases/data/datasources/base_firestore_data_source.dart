import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moonbase_skeleton/core/validators.dart';
import 'package:moonbase_skeleton/features/bases/data/datasources/base_local_data_source.dart';
import 'package:moonbase_skeleton/features/bases/data/models/base_model.dart';
import 'package:moonbase_skeleton/features/bases/data/models/invite_model.dart';
import 'package:moonbase_skeleton/features/bases/data/models/member_model.dart';
import 'package:moonbase_skeleton/features/profile/data/datasources/profile_local_data_source.dart';

/// Cloud Firestore bases — members, invites, leave.
///
/// Owner bootstrap is sequential (base then owner member row). Redeem is a
/// single [runTransaction]: invite bump + [FieldValue.arrayUnion] on
/// `memberUids` + member row create. Joiner cannot read the base until after
/// join (`isMember`), so the tx only reads the invite. Leave is a
/// [runTransaction]: [FieldValue.arrayRemove] + delete member row (owner leave
/// refused client-side).
///
/// Last-accessed is device-local ([SharedPreferences], keyed by userId) — not
/// a Firestore field — so account switches on the same device restore the
/// correct base without rules/schema changes.
class BaseFirestoreDataSource implements BaseLocalDataSource {
  BaseFirestoreDataSource({
    required ProfileLocalDataSource profiles,
    required SharedPreferences prefs,
    FirebaseFirestore? firestore,
    fb.FirebaseAuth? auth,
    Random? random,
  })  : _profiles = profiles,
        _prefs = prefs,
        _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? fb.FirebaseAuth.instance,
        _random = random ?? Random.secure();

  final ProfileLocalDataSource _profiles;
  final SharedPreferences _prefs;
  final FirebaseFirestore _db;
  final fb.FirebaseAuth _auth;
  final Random _random;

  static const _schemaVersion = 1;
  static const _defaultNickname = 'user';
  static const _kLastAccessedBasePrefix = 'mb.lastAccessedBase.';
  static const _memberPageSize = 100;
  static const _inviteAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  CollectionReference<Map<String, dynamic>> get _bases =>
      _db.collection('bases');

  DocumentReference<Map<String, dynamic>> _baseRef(String baseId) =>
      _bases.doc(baseId);

  CollectionReference<Map<String, dynamic>> _membersCol(String baseId) =>
      _baseRef(baseId).collection('members');

  CollectionReference<Map<String, dynamic>> _invitesCol(String baseId) =>
      _baseRef(baseId).collection('invites');

  CollectionReference<Map<String, dynamic>> get _inviteCodes =>
      _db.collection('inviteCodes');

  DocumentReference<Map<String, dynamic>> _inviteCodeRef(String code) =>
      _inviteCodes.doc(code);

  String? _readLastAccessedBaseId(String userId) =>
      _prefs.getString(_kLastAccessedBasePrefix + userId);

  Future<void> _writeLastAccessedBaseId(String userId, String baseId) =>
      _prefs.setString(_kLastAccessedBasePrefix + userId, baseId);

  @override
  Future<List<BaseModel>> listBasesForUser(String userId) async {
    final snap = await _bases
        .where('memberUids', arrayContains: userId)
        .orderBy('createdAt', descending: true)
        .get();

    return snap.docs
        .map((doc) => BaseModel.fromFirestore(doc.id, doc.data()))
        .toList();
  }

  @override
  Future<BaseModel> createBase({
    required String name,
    required String ownerUserId,
  }) async {
    final authUid = _auth.currentUser?.uid;
    if (authUid == null || authUid != ownerUserId) {
      throw StateError(
        'createBase requires a signed-in user matching ownerUserId',
      );
    }

    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'must be non-empty');
    }

    final nickname = await _advisoryNickname(ownerUserId);
    final ref = _bases.doc();

    await ref.set(<String, dynamic>{
      'name': trimmed,
      'ownerUid': ownerUserId,
      'memberUids': <String>[ownerUserId],
      'createdAt': FieldValue.serverTimestamp(),
      'schemaVersion': _schemaVersion,
    });

    try {
      await _membersCol(ref.id).doc(ownerUserId).set(<String, dynamic>{
        'role': 'owner',
        'nickname': nickname,
        'joinedAt': FieldValue.serverTimestamp(),
        'schemaVersion': _schemaVersion,
      });
    } catch (e) {
      // Compensating delete — rules forbid atomic batch bootstrap.
      try {
        await ref.delete();
      } catch (deleteError) {
        throw StateError(
          'createBase: owner member row failed and compensating delete of '
          'base ${ref.id} also failed; orphan base may remain. '
          'memberError=$e; deleteError=$deleteError',
        );
      }
      rethrow;
    }

    final after = await ref.get();
    final data = after.data();
    if (!after.exists || data == null) {
      throw StateError('Base create succeeded but document was missing on read');
    }
    return BaseModel.fromFirestore(ref.id, data);
  }

  @override
  Future<List<MemberModel>> listMembersForBase(String baseId) async {
    final snap =
        await _membersCol(baseId).orderBy('joinedAt', descending: false).get();
    return snap.docs
        .map((doc) => MemberModel.fromFirestore(doc.id, doc.data()))
        .toList();
  }

  @override
  Future<void> renameBase({
    required String baseId,
    required String newName,
  }) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(newName, 'newName', 'must be non-empty');
    }
    await _baseRef(baseId).update(<String, dynamic>{'name': trimmed});
  }

  @override
  Future<void> deleteBase({required String baseId}) async {
    // Sweep invites + global inviteCodes mappings (missing mapping = success).
    await _pageDeleteInvitesAndMappings(baseId);
    await _pageDeleteCollection(_membersCol(baseId));
    await _baseRef(baseId).delete();
  }

  /// Deletes invite docs and their `inviteCodes/{code}` mappings.
  /// A missing mapping is treated as success (already cleaned).
  Future<void> _pageDeleteInvitesAndMappings(String baseId) async {
    final invites = _invitesCol(baseId);
    QueryDocumentSnapshot<Map<String, dynamic>>? last;
    while (true) {
      Query<Map<String, dynamic>> q = invites.limit(_memberPageSize);
      if (last != null) {
        q = q.startAfterDocument(last);
      }
      final page = await q.get();
      if (page.docs.isEmpty) break;

      final batch = _db.batch();
      for (final docSnap in page.docs) {
        batch.delete(docSnap.reference);
        // Firestore delete of a missing doc succeeds — orphan mappings stay rare.
        batch.delete(_inviteCodeRef(docSnap.id));
      }
      await batch.commit();

      if (page.docs.length < _memberPageSize) break;
      last = page.docs.last;
    }
  }

  Future<void> _pageDeleteCollection(
    CollectionReference<Map<String, dynamic>> col,
  ) async {
    QueryDocumentSnapshot<Map<String, dynamic>>? last;
    while (true) {
      Query<Map<String, dynamic>> q = col.limit(_memberPageSize);
      if (last != null) {
        q = q.startAfterDocument(last);
      }
      final page = await q.get();
      if (page.docs.isEmpty) break;

      final batch = _db.batch();
      for (final docSnap in page.docs) {
        batch.delete(docSnap.reference);
      }
      await batch.commit();

      if (page.docs.length < _memberPageSize) break;
      last = page.docs.last;
    }
  }

  @override
  Future<BaseModel> joinBase({
    required String inviteCode,
    required String userId,
  }) async {
    final authUid = _auth.currentUser?.uid;
    if (authUid == null || authUid != userId) {
      throw StateError(
        'joinBase requires a signed-in user matching userId',
      );
    }

    final code = normalizeInviteCode(inviteCode);
    if (!isValidInviteCode(code)) {
      throw ArgumentError.value(inviteCode, 'inviteCode', 'must be 6-char code');
    }

    final baseId = await _resolveBaseIdForCode(code);
    final nickname = await _advisoryNickname(userId);
    final inviteRef = _invitesCol(baseId).doc(code);
    final baseRef = _baseRef(baseId);
    final memberRef = _membersCol(baseId).doc(userId);

    await _db.runTransaction((tx) async {
      final inviteSnap = await tx.get(inviteRef);
      if (!inviteSnap.exists) {
        throw StateError('Invite not found');
      }
      final invite = inviteSnap.data()!;
      final useCount = switch (invite['useCount']) {
        int n => n,
        num n => n.toInt(),
        _ => 0,
      };
      final maxUses = switch (invite['maxUses']) {
        int n => n,
        num n => n.toInt(),
        _ => null,
      };
      if (maxUses != null && useCount >= maxUses) {
        throw StateError('Invite has no remaining uses');
      }
      final rawExpires = invite['expiresAt'];
      if (rawExpires is Timestamp &&
          !rawExpires.toDate().toUtc().isAfter(DateTime.now().toUtc())) {
        throw StateError('Invite has expired');
      }

      tx.update(inviteRef, <String, dynamic>{'useCount': useCount + 1});
      tx.update(baseRef, <String, dynamic>{
        'memberUids': FieldValue.arrayUnion(<String>[userId]),
      });
      tx.set(memberRef, <String, dynamic>{
        'role': 'member',
        'nickname': nickname,
        'joinedAt': FieldValue.serverTimestamp(),
        'schemaVersion': _schemaVersion,
      });
    });

    final after = await baseRef.get();
    final data = after.data();
    if (!after.exists || data == null) {
      throw StateError('Join succeeded but base document was missing on read');
    }
    return BaseModel.fromFirestore(baseRef.id, data);
  }

  @override
  Future<String> generateInviteCode({required String baseId}) async {
    final authUid = _auth.currentUser?.uid;
    if (authUid == null) {
      throw StateError('generateInviteCode requires a signed-in user');
    }
    final invite = await createInvite(
      baseId: baseId,
      createdByUserId: authUid,
    );
    return invite.code;
  }

  @override
  Future<InviteModel> createInvite({
    required String baseId,
    required String createdByUserId,
    int? maxUses,
    DateTime? expiresAt,
  }) async {
    final authUid = _auth.currentUser?.uid;
    if (authUid == null || authUid != createdByUserId) {
      throw StateError(
        'createInvite requires a signed-in user matching createdByUserId',
      );
    }
    if (maxUses != null && maxUses <= 0) {
      throw ArgumentError.value(maxUses, 'maxUses', 'must be > 0 when set');
    }
    if (expiresAt != null && !expiresAt.toUtc().isAfter(DateTime.now().toUtc())) {
      throw ArgumentError.value(expiresAt, 'expiresAt', 'must be in the future');
    }

    final code = await _allocateInviteCode(baseId);

    // Wire payloads use rule field names only (not domain names).
    final invitePayload = <String, dynamic>{
      'createdBy': createdByUserId,
      'createdAt': FieldValue.serverTimestamp(),
      'useCount': 0,
      'schemaVersion': _schemaVersion,
    };
    if (maxUses != null) invitePayload['maxUses'] = maxUses;
    if (expiresAt != null) {
      invitePayload['expiresAt'] = Timestamp.fromDate(expiresAt.toUtc());
    }

    final inviteRef = _invitesCol(baseId).doc(code);
    final mappingRef = _inviteCodeRef(code);

    // Same batch: invite + global mapping (requires committed base for isOwner).
    final batch = _db.batch();
    batch.set(inviteRef, invitePayload);
    batch.set(mappingRef, <String, dynamic>{
      'baseId': baseId,
      'schemaVersion': _schemaVersion,
    });
    await batch.commit();

    final after = await inviteRef.get();
    final data = after.data();
    if (!after.exists || data == null) {
      throw StateError('Invite create succeeded but document was missing');
    }
    return InviteModel.fromFirestore(baseId, code, data);
  }

  @override
  Future<List<InviteModel>> listInvitesForBase(String baseId) async {
    final snap =
        await _invitesCol(baseId).orderBy('createdAt', descending: true).get();
    return snap.docs
        .map((doc) => InviteModel.fromFirestore(baseId, doc.id, doc.data()))
        .toList();
  }

  @override
  Future<InviteModel?> getInviteByCode(String code) async {
    final normalized = normalizeInviteCode(code);
    if (!isValidInviteCode(normalized)) return null;
    final baseId = await _lookupBaseIdForCode(normalized);
    if (baseId == null) return null;
    final snap = await _invitesCol(baseId).doc(normalized).get();
    final data = snap.data();
    if (!snap.exists || data == null) return null;
    return InviteModel.fromFirestore(baseId, normalized, data);
  }

  Future<String> _resolveBaseIdForCode(String code) async {
    final baseId = await _lookupBaseIdForCode(code);
    if (baseId == null) {
      throw StateError('Invite not found');
    }
    return baseId;
  }

  Future<String?> _lookupBaseIdForCode(String code) async {
    final snap = await _inviteCodeRef(code).get();
    final data = snap.data();
    if (!snap.exists || data == null) return null;
    final baseId = data['baseId'] as String?;
    if (baseId == null || baseId.isEmpty) return null;
    return baseId;
  }

  Future<String> _allocateInviteCode(String baseId) async {
    for (var i = 0; i < 20; i++) {
      final code = _genInviteCode();
      final existing = await _invitesCol(baseId).doc(code).get();
      if (!existing.exists) return code;
    }
    throw StateError('Could not allocate invite code');
  }

  String _genInviteCode() {
    return List.generate(
      6,
      (_) => _inviteAlphabet[_random.nextInt(_inviteAlphabet.length)],
    ).join();
  }

  /// Advisory copy from `users/{uid}`; never fails the caller.
  Future<String> _advisoryNickname(String userId) async {
    try {
      final profile = await _profiles.readProfile(userId);
      final raw = profile?.nickname.trim() ?? '';
      return _clampNickname(raw.isEmpty ? _defaultNickname : raw);
    } catch (_) {
      return _defaultNickname;
    }
  }

  String _clampNickname(String raw) {
    final trimmed = raw.trim();
    if (trimmed.length >= 2 && trimmed.length <= 24) return trimmed;
    if (trimmed.length > 24) return trimmed.substring(0, 24);
    if (trimmed.isEmpty) return _defaultNickname;
    return '${trimmed}_';
  }

  @override
  Future<void> leaveBase({
    required String baseId,
    required String userId,
  }) async {
    final authUid = _auth.currentUser?.uid;
    if (authUid == null || authUid != userId) {
      throw StateError(
        'leaveBase requires a signed-in user matching userId',
      );
    }

    final baseRef = _baseRef(baseId);
    final memberRef = _membersCol(baseId).doc(userId);

    await _db.runTransaction((tx) async {
      final baseSnap = await tx.get(baseRef);
      if (!baseSnap.exists) {
        throw StateError('Base not found');
      }
      final data = baseSnap.data()!;
      final ownerUid = data['ownerUid'] as String? ?? '';
      if (ownerUid == userId) {
        throw StateError(
          'leaveBase: owner cannot leave; ownership transfer is deferred',
        );
      }

      // Guard against the in-transaction memberUids list (same snapshot as write).
      final rawMembers = data['memberUids'];
      final memberUids = rawMembers is List
          ? rawMembers.map((e) => e.toString()).toList()
          : <String>[];
      if (!memberUids.contains(userId)) {
        throw StateError('leaveBase: user is not a member of this base');
      }

      tx.update(baseRef, <String, dynamic>{
        'memberUids': FieldValue.arrayRemove(<String>[userId]),
      });
      // Member delete is allowed because isMember() uses get() (committed state):
      // auth uid is still on memberUids mid-transaction. Write order is flexible
      // today; committing the base update first in a future change could break delete.
      tx.delete(memberRef);
    });
  }

  @override
  Future<BaseModel?> getLastAccessedBase(String userId) async {
    final lastBaseId = _readLastAccessedBaseId(userId);
    if (lastBaseId == null || lastBaseId.isEmpty) return null;

    // Only return if this user is still a member (and can therefore read the base).
    final memberSnap = await _membersCol(lastBaseId).doc(userId).get();
    if (!memberSnap.exists) return null;

    final baseSnap = await _baseRef(lastBaseId).get();
    final data = baseSnap.data();
    if (!baseSnap.exists || data == null) return null;

    return BaseModel.fromFirestore(baseSnap.id, data);
  }

  @override
  Future<void> setLastAccessedBase(String userId, String baseId) async {
    await _writeLastAccessedBaseId(userId, baseId);
  }
}
