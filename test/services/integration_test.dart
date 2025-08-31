import 'package:flutter_test/flutter_test.dart';
import 'package:moonbase_skeleton/models/base.dart';
import 'package:moonbase_skeleton/models/base_member.dart';
import 'package:moonbase_skeleton/models/invite.dart';
import 'package:moonbase_skeleton/models/enums.dart';
import 'package:moonbase_skeleton/services/bases_repository.dart';
import 'package:moonbase_skeleton/services/invites_repository.dart';

// Shared state for integration testing
class SharedTestState {
  final Map<String, Base> bases = {};
  final Map<String, List<BaseMember>> members = {};
  final Map<String, BaseInvite> invites = {};
}

// Mock implementations for integration testing
class MockBasesRepository implements BasesRepository {
  final SharedTestState _state;
  int _baseCounter = 0;
  int _memberCounter = 0;

  MockBasesRepository(this._state);

  @override
  Future<Base> createBase({required String name, String? description, String? avatarUrl}) async {
    _baseCounter++;
    final base = Base(
      id: 'base-$_baseCounter',
      name: name,
      ownerUserId: 'test-owner-id',
      description: description,
      avatarUrl: avatarUrl,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    _state.bases[base.id] = base;
    
    _memberCounter++;
    final ownerMember = BaseMember(
      id: 'member-$_memberCounter',
      baseId: base.id,
      userId: base.ownerUserId,
      role: BaseRole.owner,
      joinedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    _state.members[base.id] = [ownerMember];
    return base;
  }

  @override
  Future<void> deleteBase(String baseId) async {
    _state.bases.remove(baseId);
    _state.members.remove(baseId);
  }

  @override
  Future<Base?> getBase(String baseId) async {
    return _state.bases[baseId];
  }

  @override
  Future<List<Base>> listMyBases(String userId) async {
    return _state.bases.values.where((base) => 
      base.ownerUserId == userId || 
      _state.members[base.id]?.any((member) => member.userId == userId) == true
    ).toList();
  }

  @override
  Future<BaseMember> addMember({required String baseId, required String userId, required BaseRole role}) async {
    _memberCounter++;
    final member = BaseMember(
      id: 'member-$_memberCounter',
      baseId: baseId,
      userId: userId,
      role: role,
      joinedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    _state.members[baseId] ??= [];
    _state.members[baseId]!.add(member);
    return member;
  }

  @override
  Future<void> removeMember({required String baseId, required String userId}) async {
    _state.members[baseId]?.removeWhere((member) => member.userId == userId);
  }

  @override
  Future<List<BaseMember>> listMembers(String baseId) async {
    return _state.members[baseId] ?? [];
  }

  @override
  Future<void> upsert(Base base) async {
    _state.bases[base.id] = base;
  }

  @override
  Future<bool> isOwner({required String baseId, required String userId}) async {
    final members = _state.members[baseId] ?? [];
    return members.any((member) => 
      member.userId == userId && member.role == BaseRole.owner
    );
  }
}

class MockInvitesRepository implements InvitesRepository {
  final SharedTestState _state;
  final BasesRepository _basesRepository;
  int _inviteCounter = 0;

  MockInvitesRepository(this._state, this._basesRepository);

  @override
  Future<BaseInvite> createInvite({
    required String baseId,
    required String userId,
    int? maxUses,
    DateTime? expiresAt,
  }) async {
    // Check if user is owner
    final isOwner = await _basesRepository.isOwner(baseId: baseId, userId: userId);
    if (!isOwner) {
      throw Exception('Only owners can create invites');
    }

    _inviteCounter++;
    final invite = BaseInvite(
      id: 'invite-$_inviteCounter',
      baseId: baseId,
      code: _generateCode(),
      createdByUserId: userId,
      createdAt: DateTime.now(),
      expiresAt: expiresAt,
      maxUses: maxUses,
      usedCount: 0,
    );

    _state.invites[invite.code] = invite;
    return invite;
  }

  @override
  Future<BaseMember> redeemInvite({required String code, required String userId}) async {
    final invite = _state.invites[code];
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
    final existingMembers = await _basesRepository.listMembers(invite.baseId);
    if (existingMembers.any((member) => member.userId == userId)) {
      throw Exception('User is already a member of this base');
    }

    // Increment used count
    final updatedInvite = BaseInvite(
      id: invite.id,
      baseId: invite.baseId,
      code: invite.code,
      createdByUserId: invite.createdByUserId,
      createdAt: invite.createdAt,
      expiresAt: invite.expiresAt,
      maxUses: invite.maxUses,
      usedCount: invite.usedCount + 1,
    );
    _state.invites[code] = updatedInvite;

    // Add user as member
    final member = await _basesRepository.addMember(
      baseId: invite.baseId,
      userId: userId,
      role: BaseRole.member, // Always add as member role
    );

    return member;
  }

  @override
  Future<BaseInvite?> getByCode(String code) async {
    return _state.invites[code];
  }

  String _generateCode() {
    return 'CODE${_inviteCounter + 1}';
  }
}

void main() {
  group('Integration Tests: Base and Invite Flow', () {
    late SharedTestState sharedState;
    late MockBasesRepository basesRepository;
    late MockInvitesRepository invitesRepository;

    setUp(() {
      sharedState = SharedTestState();
      basesRepository = MockBasesRepository(sharedState);
      invitesRepository = MockInvitesRepository(sharedState, basesRepository);
    });

    test('Complete flow: Create base, list bases, create invite, redeem invite successfully', () async {
      // 1. Create base
      final base = await basesRepository.createBase(
        name: 'Test Base',
        description: 'A test base for integration testing',
      );

      expect(base.name, 'Test Base');
      expect(base.description, 'A test base for integration testing');
      expect(base.ownerUserId, 'test-owner-id');

      // 2. List bases for owner
      final ownerBases = await basesRepository.listMyBases('test-owner-id');
      expect(ownerBases, hasLength(1));
      expect(ownerBases.first.id, base.id);

      // 3. Create invite (owner only)
      final invite = await invitesRepository.createInvite(
        baseId: base.id,
        userId: base.ownerUserId,
        maxUses: 3,
        expiresAt: DateTime.now().add(const Duration(days: 7)),
      );

      expect(invite.baseId, base.id);
      expect(invite.createdByUserId, base.ownerUserId);
      expect(invite.maxUses, 3);
      expect(invite.usedCount, 0);
      expect(invite.isExpired, isFalse);
      expect(invite.isDepleted, isFalse);

      // 4. Redeem invite successfully
      final newMember = await invitesRepository.redeemInvite(
        code: invite.code,
        userId: 'new-user-123',
      );

      expect(newMember.baseId, base.id);
      expect(newMember.userId, 'new-user-123');
      expect(newMember.role, BaseRole.member);

      // 5. Verify member was added to base
      final members = await basesRepository.listMembers(base.id);
      expect(members, hasLength(2)); // Owner + new member
      expect(members.any((m) => m.userId == 'new-user-123'), isTrue);

      // 6. Verify invite usage was incremented
      final updatedInvite = await invitesRepository.getByCode(invite.code);
      expect(updatedInvite!.usedCount, 1);

      // 7. Verify new user can see the base in their list
      final newUserBases = await basesRepository.listMyBases('new-user-123');
      expect(newUserBases, hasLength(1));
      expect(newUserBases.first.id, base.id);
    });

    test('Error case: Non-owner cannot create invite', () async {
      final base = await basesRepository.createBase(name: 'Test Base');

      expect(
        () => invitesRepository.createInvite(
          baseId: base.id,
          userId: 'non-owner-id',
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Only owners can create invites'),
        )),
      );
    });

    test('Error case: Cannot redeem expired invite', () async {
      final base = await basesRepository.createBase(name: 'Test Base');
      
      final invite = await invitesRepository.createInvite(
        baseId: base.id,
        userId: base.ownerUserId,
        expiresAt: DateTime.now().subtract(const Duration(days: 1)), // Expired
      );

      expect(
        () => invitesRepository.redeemInvite(
          code: invite.code,
          userId: 'new-user',
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Invite has expired'),
        )),
      );
    });

    test('Error case: Cannot redeem depleted invite', () async {
      final base = await basesRepository.createBase(name: 'Test Base');
      
      final invite = await invitesRepository.createInvite(
        baseId: base.id,
        userId: base.ownerUserId,
        maxUses: 1, // Only one use allowed
      );

      // First redemption should succeed
      await invitesRepository.redeemInvite(
        code: invite.code,
        userId: 'user1',
      );

      // Second redemption should fail
      expect(
        () => invitesRepository.redeemInvite(
          code: invite.code,
          userId: 'user2',
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Invite has reached maximum uses'),
        )),
      );
    });

    test('Error case: Cannot redeem invalid invite code', () async {
      expect(
        () => invitesRepository.redeemInvite(
          code: 'INVALID123',
          userId: 'user-id',
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Invalid invite code'),
        )),
      );
    });

    test('Error case: Cannot redeem invite if already a member', () async {
      final base = await basesRepository.createBase(name: 'Test Base');
      
      // Add user as member first
      await basesRepository.addMember(
        baseId: base.id,
        userId: 'existing-user',
        role: BaseRole.member,
      );

      final invite = await invitesRepository.createInvite(
        baseId: base.id,
        userId: base.ownerUserId,
      );

      expect(
        () => invitesRepository.redeemInvite(
          code: invite.code,
          userId: 'existing-user',
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('User is already a member'),
        )),
      );
    });

    test('Multiple bases and invites scenario', () async {
      // Create multiple bases with same owner (simpler test)
      final base1 = await basesRepository.createBase(name: 'Base 1');
      final base2 = await basesRepository.createBase(name: 'Base 2');

      // Create invites for both bases
      final invite1 = await invitesRepository.createInvite(
        baseId: base1.id,
        userId: base1.ownerUserId,
        maxUses: 2,
      );

      final invite2 = await invitesRepository.createInvite(
        baseId: base2.id,
        userId: base2.ownerUserId,
        maxUses: 1,
      );

      // Redeem invite1 twice
      await invitesRepository.redeemInvite(code: invite1.code, userId: 'user1');
      await invitesRepository.redeemInvite(code: invite1.code, userId: 'user2');

      // Redeem invite2 once
      await invitesRepository.redeemInvite(code: invite2.code, userId: 'user3');

      // Verify invite1 is depleted
      final updatedInvite1 = await invitesRepository.getByCode(invite1.code);
      expect(updatedInvite1!.isDepleted, isTrue);

      // Verify invite2 is depleted
      final updatedInvite2 = await invitesRepository.getByCode(invite2.code);
      expect(updatedInvite2!.isDepleted, isTrue);

      // Verify all users can see their respective bases
      final user1Bases = await basesRepository.listMyBases('user1');
      final user2Bases = await basesRepository.listMyBases('user2');
      final user3Bases = await basesRepository.listMyBases('user3');

      expect(user1Bases, hasLength(1));
      expect(user1Bases.first.id, base1.id);

      expect(user2Bases, hasLength(1));
      expect(user2Bases.first.id, base1.id);

      expect(user3Bases, hasLength(1));
      expect(user3Bases.first.id, base2.id);
    });
  });
}
