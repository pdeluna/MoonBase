import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moonbase_skeleton/legacy/services/invites_repository.dart';
import 'package:moonbase_skeleton/legacy/models/invite.dart';
import 'package:moonbase_skeleton/legacy/models/base_member.dart';
import 'package:moonbase_skeleton/legacy/models/enums.dart';
import 'dart:convert';

class MockInvitesRepository implements InvitesRepository {
  final Map<String, BaseInvite> _invites = {};
  final Map<String, String> _inviteCodes = {};
  final Map<String, List<BaseMember>> _members = {};
  final Map<String, List<String>> _userBases = {};

  @override
  Future<BaseInvite> createInvite({
    required String baseId, 
    required String userId,
    int? maxUses, 
    DateTime? expiresAt
  }) async {
    final inviteId = 'invite_${_invites.length + 1}';
    String code;
    
    // Generate unique code
    do {
      code = _generateCode();
    } while (_inviteCodes.containsKey(code));

    final invite = BaseInvite(
      id: inviteId,
      baseId: baseId,
      code: code,
      createdByUserId: userId,
      createdAt: DateTime.now(),
      expiresAt: expiresAt,
      maxUses: maxUses,
      usedCount: 0,
    );

    _invites[inviteId] = invite;
    _inviteCodes[code] = inviteId;
    
    return invite;
  }

  @override
  Future<BaseMember> redeemInvite({required String code, required String userId}) async {
    final invite = await getByCode(code);
    if (invite == null) {
      throw Exception('Invalid invite code');
    }

    if (invite.isExpired) {
      throw Exception('Invite has expired');
    }

    if (invite.isDepleted) {
      throw Exception('Invite has reached maximum uses');
    }

    // Check if user is already a member
    final baseMembers = _members[invite.baseId] ?? [];
    if (baseMembers.any((member) => member.userId == userId)) {
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
    _invites[invite.id] = updatedInvite;

    // Add user as member
    final member = BaseMember(
      id: 'member_${_members.length + 1}',
      baseId: invite.baseId,
      userId: userId,
      role: BaseRole.member,
      joinedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _members[invite.baseId] = [...baseMembers, member];
    _userBases[userId] = [...(_userBases[userId] ?? []), invite.baseId];

    return member;
  }

  @override
  Future<BaseInvite?> getByCode(String code) async {
    final inviteId = _inviteCodes[code];
    return inviteId != null ? _invites[inviteId] : null;
  }

  @override
  Future<List<BaseInvite>> getByBaseId(String baseId) async {
    return _invites.values
        .where((invite) => invite.baseId == baseId)
        .toList();
  }

  String _generateCode() {
    return 'ABC123'; // Simplified for testing
  }
}

void main() {
  group('SpInvitesRepository', () {
    late SpInvitesRepository repository;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      repository = SpInvitesRepository();
    });

    tearDown(() async {
      await prefs.clear();
    });

    group('createInvite', () {
      test('should create invite with unique code', () async {
        // Setup mock base data with proper JSON structure
        await prefs.setString('mb.bases', r'{"base_1": "{\"id\":\"base_1\",\"ownerUserId\":\"user_123\",\"name\":\"Test Base\",\"description\":null,\"avatarUrl\":null,\"memberIds\":[\"user_123\"],\"createdAt\":\"2024-01-01T00:00:00.000Z\",\"updatedAt\":\"2024-01-01T00:00:00.000Z\"}"}');

        final invite = await repository.createInvite(
          baseId: 'base_1',
          userId: 'user_123',
          maxUses: 5,
        );

        expect(invite.baseId, equals('base_1'));
        expect(invite.createdByUserId, equals('user_123'));
        expect(invite.maxUses, equals(5));
        expect(invite.usedCount, equals(0));
        expect(invite.code, isNotEmpty);
        expect(invite.isExpired, isFalse);
        expect(invite.isDepleted, isFalse);

        // Verify it's saved to storage
        final retrievedInvite = await repository.getByCode(invite.code);
        expect(retrievedInvite, isNotNull);
        expect(retrievedInvite!.id, equals(invite.id));
      });

      test('should throw exception when user is not owner', () async {
        // Setup mock base data with different owner
        await prefs.setString('mb.bases', r'{"base_1": "{\"id\":\"base_1\",\"ownerUserId\":\"user_456\",\"name\":\"Test Base\",\"description\":null,\"avatarUrl\":null,\"memberIds\":[\"user_456\"],\"createdAt\":\"2024-01-01T00:00:00.000Z\",\"updatedAt\":\"2024-01-01T00:00:00.000Z\"}"}');

        expect(
          () => repository.createInvite(
            baseId: 'base_1',
            userId: 'user_123', // Not the owner
          ),
          throwsA(isA<Exception>()),
        );
      });

      test('should create invite with expiration', () async {
        await prefs.setString('mb.bases', r'{"base_1": "{\"id\":\"base_1\",\"ownerUserId\":\"user_123\",\"name\":\"Test Base\",\"description\":null,\"avatarUrl\":null,\"memberIds\":[\"user_123\"],\"createdAt\":\"2024-01-01T00:00:00.000Z\",\"updatedAt\":\"2024-01-01T00:00:00.000Z\"}"}');

        final expiresAt = DateTime.now().add(const Duration(hours: 24));
        final invite = await repository.createInvite(
          baseId: 'base_1',
          userId: 'user_123',
          expiresAt: expiresAt,
        );

        expect(invite.expiresAt, equals(expiresAt));
      });
    });

    group('redeemInvite', () {
      test('should redeem valid invite and add user as member', () async {
        // Setup mock base data
        await prefs.setString('mb.bases', r'{"base_1": "{\"id\":\"base_1\",\"ownerUserId\":\"user_123\",\"name\":\"Test Base\",\"description\":null,\"avatarUrl\":null,\"memberIds\":[\"user_123\"],\"createdAt\":\"2024-01-01T00:00:00.000Z\",\"updatedAt\":\"2024-01-01T00:00:00.000Z\"}"}');
        
        // Create invite
        final invite = await repository.createInvite(
          baseId: 'base_1',
          userId: 'user_123',
        );

        // Redeem invite
        final member = await repository.redeemInvite(
          code: invite.code,
          userId: 'user_456',
        );

        expect(member.userId, equals('user_456'));
        expect(member.baseId, equals('base_1'));
        expect(member.role, equals(BaseRole.member));

        // Verify invite usage count increased
        final updatedInvite = await repository.getByCode(invite.code);
        expect(updatedInvite!.usedCount, equals(1));
      });

      test('should throw exception for invalid code', () async {
        expect(
          () => repository.redeemInvite(
            code: 'INVALID',
            userId: 'user_456',
          ),
          throwsA(isA<Exception>()),
        );
      });

      test('should throw exception for expired invite', () async {
        await prefs.setString('mb.bases', r'{"base_1": "{\"id\":\"base_1\",\"ownerUserId\":\"user_123\",\"name\":\"Test Base\",\"description\":null,\"avatarUrl\":null,\"memberIds\":[\"user_123\"],\"createdAt\":\"2024-01-01T00:00:00.000Z\",\"updatedAt\":\"2024-01-01T00:00:00.000Z\"}"}');
        
        // Create expired invite
        final invite = await repository.createInvite(
          baseId: 'base_1',
          userId: 'user_123',
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        );

        expect(
          () => repository.redeemInvite(
            code: invite.code,
            userId: 'user_456',
          ),
          throwsA(isA<Exception>()),
        );
      });

      test('should throw exception for depleted invite', () async {
        await prefs.setString('mb.bases', r'{"base_1": "{\"id\":\"base_1\",\"ownerUserId\":\"user_123\",\"name\":\"Test Base\",\"description\":null,\"avatarUrl\":null,\"memberIds\":[\"user_123\"],\"createdAt\":\"2024-01-01T00:00:00.000Z\",\"updatedAt\":\"2024-01-01T00:00:00.000Z\"}"}');
        
        // Create invite with max uses = 1
        final invite = await repository.createInvite(
          baseId: 'base_1',
          userId: 'user_123',
          maxUses: 1,
        );

        // First redemption should work
        await repository.redeemInvite(
          code: invite.code,
          userId: 'user_456',
        );

        // Second redemption should fail
        expect(
          () => repository.redeemInvite(
            code: invite.code,
            userId: 'user_789',
          ),
          throwsA(isA<Exception>()),
        );
      });

      test('should throw exception if user is already a member', () async {
        await prefs.setString('mb.bases', r'{"base_1": "{\"id\":\"base_1\",\"ownerUserId\":\"user_123\",\"name\":\"Test Base\",\"description\":null,\"avatarUrl\":null,\"memberIds\":[\"user_123\"],\"createdAt\":\"2024-01-01T00:00:00.000Z\",\"updatedAt\":\"2024-01-01T00:00:00.000Z\"}"}');
        
        final invite = await repository.createInvite(
          baseId: 'base_1',
          userId: 'user_123',
          maxUses: 5, // Allow multiple uses
        );

        // First redemption should work
        await repository.redeemInvite(
          code: invite.code,
          userId: 'user_456',
        );

        // Set up the members data to reflect that user_456 is now a member
        // This simulates what happens when the first redemption is processed
        // Note: The _writeMembers method stores this as Maps, not JSON strings
        final memberData = {
          'base_1': [
            {'id':'member_123','baseId':'base_1','userId':'user_123','role':'owner','joinedAt':'2024-01-01T00:00:00.000Z','updatedAt':'2024-01-01T00:00:00.000Z'},
            {'id':'member_456','baseId':'base_1','userId':'user_456','role':'member','joinedAt':'2024-01-01T00:00:00.000Z','updatedAt':'2024-01-01T00:00:00.000Z'}
          ]
        };
        await prefs.setString('mb.members', jsonEncode(memberData));

        // Second redemption by same user should fail
        expect(
          () => repository.redeemInvite(
            code: invite.code,
            userId: 'user_456', // Already a member
          ),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('getByCode', () {
      test('should return invite for valid code', () async {
        await prefs.setString('mb.bases', r'{"base_1": "{\"id\":\"base_1\",\"ownerUserId\":\"user_123\",\"name\":\"Test Base\",\"description\":null,\"avatarUrl\":null,\"memberIds\":[\"user_123\"],\"createdAt\":\"2024-01-01T00:00:00.000Z\",\"updatedAt\":\"2024-01-01T00:00:00.000Z\"}"}');
        
        final invite = await repository.createInvite(
          baseId: 'base_1',
          userId: 'user_123',
        );

        final retrievedInvite = await repository.getByCode(invite.code);
        expect(retrievedInvite, isNotNull);
        expect(retrievedInvite!.id, equals(invite.id));
        expect(retrievedInvite.baseId, equals(invite.baseId));
      });

      test('should return null for invalid code', () async {
        final invite = await repository.getByCode('INVALID');
        expect(invite, isNull);
      });
    });
  });
}
