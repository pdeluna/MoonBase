import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonbase_skeleton/features/bases/data/models/member_model.dart';

void main() {
  group('MemberModel Firestore codec', () {
    test('toFirestore emits exactly schema keys', () {
      final joined = DateTime.utc(2024, 6, 1, 12);
      final model = MemberModel(
        userId: 'uid_alice',
        role: 'owner',
        nickname: 'Alice',
        joinedAt: joined,
      );

      final map = model.toFirestore();
      expect(map.keys.toSet(), {'role', 'nickname', 'joinedAt', 'schemaVersion'});
      expect(map['role'], 'owner');
      expect(map['nickname'], 'Alice');
      expect(map['schemaVersion'], 1);
      expect(map['joinedAt'], isA<Timestamp>());
      expect(map.containsKey('userId'), isFalse);
    });

    test('fromFirestore maps doc id and Timestamp', () {
      final joined = DateTime.utc(2024, 6, 1, 12);
      final model = MemberModel.fromFirestore('uid_bob', {
        'role': 'member',
        'nickname': 'Bob',
        'joinedAt': Timestamp.fromDate(joined),
        'schemaVersion': 1,
      });

      expect(model.userId, 'uid_bob');
      expect(model.role, 'member');
      expect(model.nickname, 'Bob');
      expect(model.joinedAt, joined);
      expect(model.toEntity().userId.value, 'uid_bob');
    });
  });
}
