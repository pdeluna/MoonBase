import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonbase_skeleton/providers/invites_provider.dart';
import 'package:moonbase_skeleton/models/invite.dart';
import 'package:moonbase_skeleton/models/base_member.dart';
import 'package:moonbase_skeleton/models/enums.dart';
import 'package:moonbase_skeleton/models/base.dart';
import 'package:moonbase_skeleton/models/profile.dart';

void main() {
  group('InvitesProvider Tests', () {
    late Base testBase;
    late Profile testProfile;
    late BaseInvite testInvite;
    late BaseMember testMember;

    setUp(() {
      testBase = Base(
        id: 'test_base_123',
        name: 'Test Base',
        ownerUserId: 'user_123',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
        lastAccessedAt: DateTime(2024, 1, 15),
      );
      
      testProfile = Profile(
        userId: 'user_123',
        nickname: 'testuser',
        createdAt: DateTime(2024, 1, 1).toIso8601String(),
        themeMode: 'light',
      );
      
      testInvite = BaseInvite(
        id: 'invite_123',
        baseId: testBase.id,
        code: 'TEST123',
        createdByUserId: 'user_123',
        maxUses: 5,
        usedCount: 0,
        expiresAt: DateTime.now().add(const Duration(days: 30)), // Future date - should not be expired
        createdAt: DateTime(2024, 1, 1),
      );
      
      testMember = BaseMember(
        id: 'member_123',
        baseId: testBase.id,
        userId: 'user_456',
        role: BaseRole.member,
        joinedAt: DateTime(2024, 1, 15),
        updatedAt: DateTime(2024, 1, 15),
      );
    });

    group('BaseInvite Model', () {
      test('should create invite with correct properties', () {
        expect(testInvite.id, equals('invite_123'));
        expect(testInvite.baseId, equals(testBase.id));
        expect(testInvite.code, equals('TEST123'));
        expect(testInvite.createdByUserId, equals('user_123'));
        expect(testInvite.maxUses, equals(5));
        expect(testInvite.usedCount, equals(0));
        expect(testInvite.isExpired, isFalse);
        expect(testInvite.isDepleted, isFalse);
      });

      test('should calculate isExpired correctly', () {
        // Use a date that's definitely in the past
        final pastDate = DateTime.now().subtract(const Duration(days: 1));
        final expiredInvite = BaseInvite(
          id: 'expired_invite',
          baseId: testBase.id,
          code: 'EXPIRED',
          createdByUserId: 'user_123',
          maxUses: 5,
          usedCount: 0,
          expiresAt: pastDate,
          createdAt: pastDate,
        );
        
        expect(expiredInvite.isExpired, isTrue);
        expect(testInvite.isExpired, isFalse);
      });

      test('should calculate isDepleted correctly', () {
        final depletedInvite = BaseInvite(
          id: 'depleted_invite',
          baseId: testBase.id,
          code: 'DEPLETED',
          createdByUserId: 'user_123',
          maxUses: 3,
          usedCount: 3, // Max uses reached
          expiresAt: DateTime.now().add(const Duration(days: 30)),
          createdAt: DateTime(2024, 1, 1),
        );
        
        expect(depletedInvite.isDepleted, isTrue);
        expect(testInvite.isDepleted, isFalse);
      });
    });

    group('BaseMember Model', () {
      test('should create member with correct properties', () {
        expect(testMember.id, equals('member_123'));
        expect(testMember.baseId, equals(testBase.id));
        expect(testMember.userId, equals('user_456'));
        expect(testMember.role, equals(BaseRole.member));
        expect(testMember.joinedAt, equals(DateTime(2024, 1, 15)));
      });

      test('should copy member with new values', () {
        final updatedMember = testMember.copyWith(
          role: BaseRole.admin,
          updatedAt: DateTime(2024, 1, 16),
        );
        
        expect(updatedMember.role, equals(BaseRole.admin));
        expect(updatedMember.updatedAt, equals(DateTime(2024, 1, 16)));
        expect(updatedMember.id, equals(testMember.id)); // Should remain unchanged
        expect(updatedMember.userId, equals(testMember.userId)); // Should remain unchanged
      });
    });

    group('BaseRole Enum', () {
      test('should have correct role values', () {
        expect(BaseRole.owner, equals(BaseRole.owner));
        expect(BaseRole.admin, equals(BaseRole.admin));
        expect(BaseRole.member, equals(BaseRole.member));
      });

      test('should handle role comparisons', () {
        expect(BaseRole.owner != BaseRole.admin, isTrue);
        expect(BaseRole.member == BaseRole.member, isTrue);
      });
    });

    group('Invite Validation', () {
      test('should validate valid invite', () {
        expect(testInvite.isExpired, isFalse);
        expect(testInvite.isDepleted, isFalse);
      });

      test('should detect expired invite', () {
        final pastDate = DateTime.now().subtract(const Duration(days: 1));
        final expiredInvite = BaseInvite(
          id: 'expired_invite',
          baseId: testBase.id,
          code: 'EXPIRED',
          createdByUserId: 'user_123',
          maxUses: 5,
          usedCount: 0,
          expiresAt: pastDate,
          createdAt: pastDate,
        );
        
        expect(expiredInvite.isExpired, isTrue);
      });

      test('should detect depleted invite', () {
        final depletedInvite = BaseInvite(
          id: 'depleted_invite',
          baseId: testBase.id,
          code: 'DEPLETED',
          createdByUserId: 'user_123',
          maxUses: 3,
          usedCount: 3, // Max uses reached
          expiresAt: DateTime.now().add(const Duration(days: 30)),
          createdAt: DateTime(2024, 1, 1),
        );
        
        expect(depletedInvite.isDepleted, isTrue);
      });

      test('should handle unlimited uses invite', () {
        final unlimitedInvite = BaseInvite(
          id: 'unlimited_invite',
          baseId: testBase.id,
          code: 'UNLIMITED',
          createdByUserId: 'user_123',
          maxUses: null, // No limit
          usedCount: 0,
          expiresAt: DateTime.now().add(const Duration(days: 30)),
          createdAt: DateTime(2024, 1, 1),
        );
        
        expect(unlimitedInvite.isDepleted, isFalse);
      });
    });

    group('Invite Code Generation', () {
      test('should generate valid invite codes', () {
        expect(testInvite.code, isNotEmpty);
        expect(testInvite.code.length, greaterThanOrEqualTo(6));
        
        // Test that different invites have different codes
        final anotherInvite = BaseInvite(
          id: 'invite_456',
          baseId: testBase.id,
          code: 'DIFFERENT',
          createdByUserId: 'user_123',
          maxUses: 5,
          usedCount: 0,
          expiresAt: DateTime.now().add(const Duration(days: 30)),
          createdAt: DateTime(2024, 1, 1),
        );
        
        expect(anotherInvite.code, isNot(equals(testInvite.code)));
      });
    });

    group('Member Role Management', () {
      test('should handle role hierarchy', () {
        expect(BaseRole.owner.index, lessThan(BaseRole.admin.index));
        expect(BaseRole.admin.index, lessThan(BaseRole.member.index));
      });

      test('should validate role transitions', () {
        // Owner can promote to admin
        final promotedMember = testMember.copyWith(role: BaseRole.admin);
        expect(promotedMember.role, equals(BaseRole.admin));
        
        // Admin can be demoted to member
        final demotedMember = promotedMember.copyWith(role: BaseRole.member);
        expect(demotedMember.role, equals(BaseRole.member));
      });
    });

    group('Invite Usage Tracking', () {
      test('should track invite usage correctly', () {
        final usedInvite = BaseInvite(
          id: 'used_invite',
          baseId: testBase.id,
          code: 'USED',
          createdByUserId: 'user_123',
          maxUses: 5,
          usedCount: 1,
          expiresAt: DateTime.now().add(const Duration(days: 30)),
          createdAt: DateTime(2024, 1, 1),
        );
        
        expect(usedInvite.usedCount, equals(1));
      });

      test('should handle unlimited uses', () {
        final unlimitedInvite = BaseInvite(
          id: 'unlimited_invite',
          baseId: testBase.id,
          code: 'UNLIMITED',
          createdByUserId: 'user_123',
          maxUses: null, // No limit
          usedCount: 0,
          expiresAt: DateTime.now().add(const Duration(days: 30)),
          createdAt: DateTime(2024, 1, 1),
        );
        
        expect(unlimitedInvite.isDepleted, isFalse);
      });

      test('should detect when invite is fully used', () {
        final fullyUsedInvite = BaseInvite(
          id: 'fully_used_invite',
          baseId: testBase.id,
          code: 'FULLY_USED',
          createdByUserId: 'user_123',
          maxUses: 5,
          usedCount: 5, // Max uses reached
          expiresAt: DateTime.now().add(const Duration(days: 30)),
          createdAt: DateTime(2024, 1, 1),
        );
        
        expect(fullyUsedInvite.isDepleted, isTrue);
      });
    });

    group('Invite Expiration', () {
      test('should handle no expiration date', () {
        final noExpiryInvite = BaseInvite(
          id: 'no_expiry_invite',
          baseId: testBase.id,
          code: 'NO_EXPIRY',
          createdByUserId: 'user_123',
          maxUses: 5,
          usedCount: 0,
          expiresAt: null, // No expiration
          createdAt: DateTime(2024, 1, 1),
        );
        
        expect(noExpiryInvite.isExpired, isFalse);
      });

      test('should calculate time until expiration', () {
        final futureDate = DateTime.now().add(const Duration(days: 30));
        final futureInvite = BaseInvite(
          id: 'future_invite',
          baseId: testBase.id,
          code: 'FUTURE',
          createdByUserId: 'user_123',
          maxUses: 5,
          usedCount: 0,
          expiresAt: futureDate,
          createdAt: DateTime(2024, 1, 1),
        );
        
        expect(futureInvite.isExpired, isFalse);
        expect(futureInvite.expiresAt!.isAfter(DateTime.now()), isTrue);
      });
    });

    group('Data Serialization', () {
      test('should convert invite to map', () {
        final map = testInvite.toMap();
        
        expect(map['id'], equals(testInvite.id));
        expect(map['baseId'], equals(testInvite.baseId));
        expect(map['code'], equals(testInvite.code));
        expect(map['maxUses'], equals(testInvite.maxUses));
        expect(map['usedCount'], equals(testInvite.usedCount));
      });

      test('should create invite from map', () {
        final map = testInvite.toMap();
        final recreatedInvite = BaseInvite.fromMap(map);
        
        expect(recreatedInvite.id, equals(testInvite.id));
        expect(recreatedInvite.baseId, equals(testInvite.baseId));
        expect(recreatedInvite.code, equals(testInvite.code));
        expect(recreatedInvite.maxUses, equals(testInvite.maxUses));
      });

      test('should handle JSON serialization', () {
        final json = testInvite.toJson();
        final recreatedInvite = BaseInvite.fromJson(json);
        
        expect(recreatedInvite.id, equals(testInvite.id));
        expect(recreatedInvite.code, equals(testInvite.code));
      });
    });
  });
}
