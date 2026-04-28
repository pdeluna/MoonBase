import 'package:flutter_test/flutter_test.dart';
import 'package:moonbase_skeleton/legacy/models/base.dart';

void main() {
  group('Base Selection Logic Tests', () {
    test('should find the most recently accessed base by lastAccessedAt timestamp', () {
      // Create test bases with different last accessed dates
      final base1 = Base(
        id: '1',
        name: 'Base 1',
        ownerUserId: 'user1',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
        lastAccessedAt: DateTime(2024, 1, 15),
      );
      
      final base2 = Base(
        id: '2',
        name: 'Base 2',
        ownerUserId: 'user1',
        createdAt: DateTime(2024, 2, 1),
        updatedAt: DateTime(2024, 2, 1),
        lastAccessedAt: DateTime(2024, 2, 15), // Most recently accessed
      );
      
      final base3 = Base(
        id: '3',
        name: 'Base 3',
        ownerUserId: 'user1',
        createdAt: DateTime(2023, 12, 1),
        updatedAt: DateTime(2023, 12, 1),
        lastAccessedAt: DateTime(2024, 1, 10), // Least recently accessed
      );
      
      final bases = [base1, base2, base3];
      
      // Test that the most recently accessed base is found
      final mostRecentBase = bases.reduce((a, b) {
        final aTime = a.lastAccessedAt ?? a.createdAt;
        final bTime = b.lastAccessedAt ?? b.createdAt;
        return aTime.isAfter(bTime) ? a : b;
      });
      
      expect(mostRecentBase, equals(base2));
    });

    test('should fall back to createdAt when lastAccessedAt is null', () {
      final base1 = Base(
        id: '1',
        name: 'Base 1',
        ownerUserId: 'user1',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
        lastAccessedAt: null, // No access time
      );
      
      final base2 = Base(
        id: '2',
        name: 'Base 2',
        ownerUserId: 'user1',
        createdAt: DateTime(2024, 2, 1), // More recent creation
        updatedAt: DateTime(2024, 2, 1),
        lastAccessedAt: null, // No access time
      );
      
      final bases = [base1, base2];
      
      // Test that it falls back to creation date when lastAccessedAt is null
      final mostRecentBase = bases.reduce((a, b) {
        final aTime = a.lastAccessedAt ?? a.createdAt;
        final bTime = b.lastAccessedAt ?? b.createdAt;
        return aTime.isAfter(bTime) ? a : b;
      });
      
      expect(mostRecentBase, equals(base2));
    });

    test('should handle empty list gracefully', () {
      final bases = <Base>[];
      
      // This should not throw an error
      expect(() {
        if (bases.isNotEmpty) {
          bases.reduce((a, b) {
            final aTime = a.lastAccessedAt ?? a.createdAt;
            final bTime = b.lastAccessedAt ?? b.createdAt;
            return aTime.isAfter(bTime) ? a : b;
          });
        }
      }, returnsNormally);
    });

    test('should handle single base correctly', () {
      final base1 = Base(
        id: '1',
        name: 'Base 1',
        ownerUserId: 'user1',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
        lastAccessedAt: DateTime(2024, 1, 15),
      );
      
      final bases = [base1];
      
      // With a single base, it should be the most recent
      final mostRecentBase = bases.reduce((a, b) {
        final aTime = a.lastAccessedAt ?? a.createdAt;
        final bTime = b.lastAccessedAt ?? b.createdAt;
        return aTime.isAfter(bTime) ? a : b;
      });
      
      expect(mostRecentBase, equals(base1));
    });

    test('should handle bases with same last accessed date', () {
      final base1 = Base(
        id: '1',
        name: 'Base 1',
        ownerUserId: 'user1',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
        lastAccessedAt: DateTime(2024, 1, 15), // Same access time
      );
      
      final base2 = Base(
        id: '2',
        name: 'Base 2',
        ownerUserId: 'user1',
        createdAt: DateTime(2024, 2, 1),
        updatedAt: DateTime(2024, 2, 1),
        lastAccessedAt: DateTime(2024, 1, 15), // Same access time
      );
      
      final bases = [base1, base2];
      
      // When last accessed dates are equal, the second one is returned because isAfter returns false for equal dates
      final mostRecentBase = bases.reduce((a, b) {
        final aTime = a.lastAccessedAt ?? a.createdAt;
        final bTime = b.lastAccessedAt ?? b.createdAt;
        return aTime.isAfter(bTime) ? a : b;
      });
      
      expect(mostRecentBase.id, equals('2'));
    });
  });
}
