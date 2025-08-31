import 'package:flutter_test/flutter_test.dart';
import 'package:moonbase_skeleton/models/base.dart';
import 'package:moonbase_skeleton/models/base_member.dart';
import 'package:moonbase_skeleton/models/invite.dart';
import 'package:moonbase_skeleton/models/enums.dart';
import 'package:moonbase_skeleton/services/invites_repository.dart';
import 'package:moonbase_skeleton/services/bases_repository.dart';

// Mock implementation for testing
class MockInvitesRepository implements InvitesRepository {
  final Map<String, BaseInvite> _invites = {};
  final BasesRepository _basesRepository;

  MockInvitesRepository(this._basesRepository);

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

    final invite = BaseInvite(
      id: 'invite-${DateTime.now().millisecondsSinceEpoch}',
      baseId: baseId,
      code: _generateCode(),
      createdByUserId: userId,
      createdAt: DateTime.now(),
      expiresAt: expiresAt,
      maxUses: maxUses,
      usedCount: 0,
    );

    _invites[invite.code] = invite;
    return invite;
  }

  @override
  Future<BaseMember> redeemInvite({required String code, required String userId}) async {
    final invite = _invites[code];
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
    _invites[code] = updatedInvite;

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
    return _invites[code];
  }

  String _generateCode() {
    final random = DateTime.now().millisecondsSinceEpoch % 1000000;
    return random.toString().padLeft(6, '0');
  }
}

// Mock BasesRepository for testing
class MockBasesRepository implements BasesRepository {
  final Map<String, Base> _bases = {};
  final Map<String, List<BaseMember>> _members = {};

  @override
  Future<Base> createBase({required String name, String? description, String? avatarUrl}) async {
    final base = Base(
      id: 'base-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      ownerUserId: 'test-owner-id',
      description: description,
      avatarUrl: avatarUrl,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    _bases[base.id] = base;
    
    final ownerMember = BaseMember(
      id: 'member-${DateTime.now().millisecondsSinceEpoch}',
      baseId: base.id,
      userId: base.ownerUserId,
      role: BaseRole.owner,
      joinedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    _members[base.id] = [ownerMember];
    return base;
  }

  @override
  Future<void> deleteBase(String baseId) async {
    _bases.remove(baseId);
    _members.remove(baseId);
  }

  @override
  Future<Base?> getBase(String baseId) async {
    return _bases[baseId];
  }

  @override
  Future<List<Base>> listMyBases(String userId) async {
    return _bases.values.where((base) => 
      base.ownerUserId == userId || 
      _members[base.id]?.any((member) => member.userId == userId) == true
    ).toList();
  }

  @override
  Future<BaseMember> addMember({required String baseId, required String userId, required BaseRole role}) async {
    final member = BaseMember(
      id: 'member-${DateTime.now().millisecondsSinceEpoch}',
      baseId: baseId,
      userId: userId,
      role: role,
      joinedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    _members[baseId] ??= [];
    _members[baseId]!.add(member);
    return member;
  }

  @override
  Future<void> removeMember({required String baseId, required String userId}) async {
    _members[baseId]?.removeWhere((member) => member.userId == userId);
  }

  @override
  Future<List<BaseMember>> listMembers(String baseId) async {
    return _members[baseId] ?? [];
  }

  @override
  Future<void> upsert(Base base) async {
    _bases[base.id] = base;
  }

  @override
  Future<bool> isOwner({required String baseId, required String userId}) async {
    final members = _members[baseId] ?? [];
    return members.any((member) => 
      member.userId == userId && member.role == BaseRole.owner
    );
  }
}

void main() {
  group('InvitesRepository Tests', () {
    late MockBasesRepository basesRepository;
    late MockInvitesRepository invitesRepository;

    setUp(() {
      basesRepository = MockBasesRepository();
      invitesRepository = MockInvitesRepository(basesRepository);
    });

    group('Create Invite', () {
      test('should create invite when user is owner', () async {
        final base = await basesRepository.createBase(name: 'Test Base');
        
        final invite = await invitesRepository.createInvite(
          baseId: base.id,
          userId: base.ownerUserId,
        );

        expect(invite.baseId, base.id);
        expect(invite.createdByUserId, base.ownerUserId);
        expect(invite.code, isNotEmpty);
        expect(invite.usedCount, 0);
        expect(invite.expiresAt, isNull);
        expect(invite.maxUses, isNull);
      });

      test('should create invite with expiration and max uses', () async {
        final base = await basesRepository.createBase(name: 'Test Base');
        final expiresAt = DateTime.now().add(const Duration(days: 7));
        
        final invite = await invitesRepository.createInvite(
          baseId: base.id,
          userId: base.ownerUserId,
          maxUses: 5,
          expiresAt: expiresAt,
        );

        expect(invite.maxUses, 5);
        expect(invite.expiresAt, expiresAt);
      });

      test('should throw exception when non-owner tries to create invite', () async {
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
    });

    group('Redeem Invite - Success Cases', () {
      test('should successfully redeem valid invite', () async {
        final base = await basesRepository.createBase(name: 'Test Base');
        final invite = await invitesRepository.createInvite(
          baseId: base.id,
          userId: base.ownerUserId,
        );

        final member = await invitesRepository.redeemInvite(
          code: invite.code,
          userId: 'new-user-id',
        );

        expect(member.baseId, base.id);
        expect(member.userId, 'new-user-id');
        expect(member.role, BaseRole.member);
      });

      test('should increment used count when invite is redeemed', () async {
        final base = await basesRepository.createBase(name: 'Test Base');
        final invite = await invitesRepository.createInvite(
          baseId: base.id,
          userId: base.ownerUserId,
        );

        await invitesRepository.redeemInvite(
          code: invite.code,
          userId: 'user1',
        );

        final updatedInvite = await invitesRepository.getByCode(invite.code);
        expect(updatedInvite!.usedCount, 1);
      });

      test('should add user as member with member role', () async {
        final base = await basesRepository.createBase(name: 'Test Base');
        final invite = await invitesRepository.createInvite(
          baseId: base.id,
          userId: base.ownerUserId,
        );

        final member = await invitesRepository.redeemInvite(
          code: invite.code,
          userId: 'new-member-id',
        );

        expect(member.role, BaseRole.member);
        
        final members = await basesRepository.listMembers(base.id);
        expect(members.any((m) => m.userId == 'new-member-id'), isTrue);
      });
    });

    group('Redeem Invite - Error Cases', () {
      test('should throw exception for invalid invite code', () async {
        expect(
          () => invitesRepository.redeemInvite(
            code: 'INVALID',
            userId: 'user-id',
          ),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Invalid invite code'),
          )),
        );
      });

      test('should throw exception for expired invite', () async {
        final base = await basesRepository.createBase(name: 'Test Base');
        final pastDate = DateTime.now().subtract(const Duration(days: 1));
        
        final invite = await invitesRepository.createInvite(
          baseId: base.id,
          userId: base.ownerUserId,
          expiresAt: pastDate,
        );

        expect(
          () => invitesRepository.redeemInvite(
            code: invite.code,
            userId: 'user-id',
          ),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Invite has expired'),
          )),
        );
      });

      test('should throw exception for depleted invite', () async {
        final base = await basesRepository.createBase(name: 'Test Base');
        final invite = await invitesRepository.createInvite(
          baseId: base.id,
          userId: base.ownerUserId,
          maxUses: 1,
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

      test('should throw exception when user is already a member', () async {
        final base = await basesRepository.createBase(name: 'Test Base');
        final invite = await invitesRepository.createInvite(
          baseId: base.id,
          userId: base.ownerUserId,
        );

        // Add user as member first
        await basesRepository.addMember(
          baseId: base.id,
          userId: 'existing-user',
          role: BaseRole.member,
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
    });

    group('Get Invite', () {
      test('should get invite by code', () async {
        final base = await basesRepository.createBase(name: 'Test Base');
        final createdInvite = await invitesRepository.createInvite(
          baseId: base.id,
          userId: base.ownerUserId,
        );

        final retrievedInvite = await invitesRepository.getByCode(createdInvite.code);

        expect(retrievedInvite, isNotNull);
        expect(retrievedInvite!.id, createdInvite.id);
        expect(retrievedInvite.code, createdInvite.code);
        expect(retrievedInvite.baseId, createdInvite.baseId);
      });

      test('should return null for non-existent invite code', () async {
        final invite = await invitesRepository.getByCode('NONEXISTENT');

        expect(invite, isNull);
      });
    });

    group('Invite Properties', () {
      test('should correctly identify expired invite', () async {
        final base = await basesRepository.createBase(name: 'Test Base');
        final pastDate = DateTime.now().subtract(const Duration(days: 1));
        
        final invite = await invitesRepository.createInvite(
          baseId: base.id,
          userId: base.ownerUserId,
          expiresAt: pastDate,
        );

        expect(invite.isExpired, isTrue);
      });

      test('should correctly identify non-expired invite', () async {
        final base = await basesRepository.createBase(name: 'Test Base');
        final futureDate = DateTime.now().add(const Duration(days: 1));
        
        final invite = await invitesRepository.createInvite(
          baseId: base.id,
          userId: base.ownerUserId,
          expiresAt: futureDate,
        );

        expect(invite.isExpired, isFalse);
      });

      test('should correctly identify depleted invite', () async {
        final base = await basesRepository.createBase(name: 'Test Base');
        final invite = await invitesRepository.createInvite(
          baseId: base.id,
          userId: base.ownerUserId,
          maxUses: 1,
        );

        // Redeem once to reach max uses
        await invitesRepository.redeemInvite(
          code: invite.code,
          userId: 'user1',
        );

        final updatedInvite = await invitesRepository.getByCode(invite.code);
        expect(updatedInvite!.isDepleted, isTrue);
      });

      test('should correctly identify non-depleted invite', () async {
        final base = await basesRepository.createBase(name: 'Test Base');
        final invite = await invitesRepository.createInvite(
          baseId: base.id,
          userId: base.ownerUserId,
          maxUses: 5,
        );

        expect(invite.isDepleted, isFalse);
      });
    });
  });
}
