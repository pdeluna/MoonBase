import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonbase_skeleton/features/profile/data/models/profile_model.dart';

void main() {
  group('ProfileModel Firestore codec', () {
    test('toFirestore emits exactly schema keys with Timestamp createdAt', () {
      final created = DateTime.utc(2024, 6, 1, 12);
      final model = ProfileModel(
        userId: 'uid_1',
        nickname: 'Alice',
        avatarUrl: 'https://example.com/a.png',
        themeMode: 'dark',
        createdAt: created,
        updatedAt: DateTime.utc(2024, 7, 1),
      );

      final map = model.toFirestore();
      expect(map.keys.toSet(), {'nickname', 'themeMode', 'createdAt', 'schemaVersion'});
      expect(map['nickname'], 'Alice');
      expect(map['themeMode'], 'dark');
      expect(map['schemaVersion'], 1);
      expect(map['createdAt'], isA<Timestamp>());
      expect((map['createdAt'] as Timestamp).toDate().toUtc(), created);
      expect(map.containsKey('avatarUrl'), isFalse);
      expect(map.containsKey('userId'), isFalse);
      expect(map.containsKey('updatedAt'), isFalse);
    });

    test('fromFirestore maps doc id and Timestamp; avatarUrl stays null', () {
      final created = DateTime.utc(2024, 6, 1, 12);
      final model = ProfileModel.fromFirestore('uid_1', {
        'nickname': 'Bob',
        'themeMode': 'light',
        'createdAt': Timestamp.fromDate(created),
        'schemaVersion': 1,
      });

      expect(model.userId, 'uid_1');
      expect(model.nickname, 'Bob');
      expect(model.themeMode, 'light');
      expect(model.createdAt, created);
      expect(model.updatedAt, created);
      expect(model.avatarUrl, isNull);
    });
  });
}
