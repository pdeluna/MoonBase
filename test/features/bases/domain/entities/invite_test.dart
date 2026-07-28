import 'package:flutter_test/flutter_test.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/invite.dart';

void main() {
  group('Invite entity rules', () {
    final createdAt = DateTime.utc(2024, 1, 1);

    Invite build({
      String id = 'invite_123',
      String code = 'TEST123',
      DateTime? expiresAt,
      int? maxUses = 5,
      int usedCount = 0,
    }) =>
        Invite(
          id: id.iid,
          baseId: 'base_123'.bid,
          code: code,
          createdByUserId: 'user_123'.uid,
          createdAt: createdAt,
          expiresAt: expiresAt,
          maxUses: maxUses,
          usedCount: usedCount,
        );

    test('creates with expected properties', () {
      final invite = build(
        expiresAt: DateTime.now().add(const Duration(days: 30)),
      );

      expect(invite.id, 'invite_123'.iid);
      expect(invite.baseId, 'base_123'.bid);
      expect(invite.code, 'TEST123');
      expect(invite.createdByUserId, 'user_123'.uid);
      expect(invite.maxUses, 5);
      expect(invite.usedCount, 0);
      expect(invite.isExpired, isFalse);
      expect(invite.isDepleted, isFalse);
      expect(invite.isValid, isTrue);
    });

    group('isExpired', () {
      test('true when expiresAt is in the past', () {
        final invite = build(
          expiresAt: DateTime.now().subtract(const Duration(days: 1)),
        );
        expect(invite.isExpired, isTrue);
        expect(invite.isValid, isFalse);
      });

      test('false when expiresAt is in the future', () {
        final invite = build(
          expiresAt: DateTime.now().add(const Duration(days: 30)),
        );
        expect(invite.isExpired, isFalse);
      });

      test('false when expiresAt is null (no expiry)', () {
        final invite = build(expiresAt: null);
        expect(invite.isExpired, isFalse);
        expect(invite.isValid, isTrue);
      });
    });

    group('isDepleted', () {
      test('true when usedCount reaches maxUses', () {
        final invite = build(
          maxUses: 3,
          usedCount: 3,
          expiresAt: DateTime.now().add(const Duration(days: 30)),
        );
        expect(invite.isDepleted, isTrue);
        expect(invite.isValid, isFalse);
      });

      test('true when usedCount exceeds maxUses', () {
        final invite = build(maxUses: 5, usedCount: 5);
        expect(invite.isDepleted, isTrue);
      });

      test('false when under maxUses', () {
        final invite = build(maxUses: 5, usedCount: 1);
        expect(invite.isDepleted, isFalse);
        expect(invite.usedCount, 1);
      });

      test('false when maxUses is null (unlimited)', () {
        final invite = build(maxUses: null, usedCount: 100);
        expect(invite.isDepleted, isFalse);
        expect(invite.isValid, isTrue);
      });
    });

    group('isValid', () {
      test('false when both expired and depleted', () {
        final invite = build(
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
          maxUses: 1,
          usedCount: 1,
        );
        expect(invite.isExpired, isTrue);
        expect(invite.isDepleted, isTrue);
        expect(invite.isValid, isFalse);
      });

      test('true only when neither expired nor depleted', () {
        final invite = build(
          expiresAt: DateTime.now().add(const Duration(days: 1)),
          maxUses: 2,
          usedCount: 0,
        );
        expect(invite.isValid, isTrue);
      });
    });

    test('equality is by all fields', () {
      final a = build(code: 'ABC123', maxUses: 5);
      final b = build(code: 'ABC123', maxUses: 5);
      final c = build(code: 'OTHER', maxUses: 5);

      expect(a, b);
      expect(a, isNot(c));
      expect(a.hashCode, b.hashCode);
    });
  });
}
