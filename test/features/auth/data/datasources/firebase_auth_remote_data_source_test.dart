import 'package:flutter_test/flutter_test.dart';
import 'package:moonbase_skeleton/features/auth/data/datasources/firebase_auth_remote_data_source.dart';

void main() {
  group('FirebaseAuthRemoteDataSource.nicknameFromEmail', () {
    test('uses local-part before @', () {
      expect(
        FirebaseAuthRemoteDataSource.nicknameFromEmail('owner@example.com'),
        'owner',
      );
    });

    test('falls back to full string without @', () {
      expect(
        FirebaseAuthRemoteDataSource.nicknameFromEmail('no-at-sign'),
        'no-at-sign',
      );
    });
  });
}
