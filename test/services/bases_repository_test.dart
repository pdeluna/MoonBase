import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moonbase_skeleton/services/bases_repository.dart';
import 'package:moonbase_skeleton/models/base.dart';
import 'package:moonbase_skeleton/models/base_member.dart';
import 'package:moonbase_skeleton/models/enums.dart';

class MockBasesRepository implements BasesRepository {
  final Map<String, Base> _bases = {};
  final Map<String, List<BaseMember>> _members = {};
  final Map<String, List<String>> _userBases = {};

  @override
  Future<Base> createBase({required String name, String? description, String? avatarUrl, required String userId}) async {
    final baseId = 'base_${_bases.length + 1}';
    
    final base = Base(
      id: baseId,
      name: name,
      ownerUserId: userId,
      description: description,
      avatarUrl: avatarUrl,
      memberIds: [userId],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _bases[baseId] = base;
    _userBases[userId] = [...(_userBases[userId] ?? []), baseId];
    
    // Add owner as member
    final member = BaseMember(
      id: 'member_${_members.length + 1}',
      baseId: baseId,
      userId: userId,
      role: BaseRole.owner,
      joinedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    _members[baseId] = [member];
    
    return base;
  }

  @override
  Future<void> deleteBase(String baseId, {required String userId}) async {
    _bases.remove(baseId);
    _members.remove(baseId);
    
    // Remove from all users' lists
    for (final userId in _userBases.keys) {
      _userBases[userId]?.remove(baseId);
    }
  }

  @override
  Future<Base?> getBase(String baseId) async {
    return _bases[baseId];
  }

  @override
  Future<List<Base>> listMyBases(String userId) async {
    final baseIds = _userBases[userId] ?? [];
    return baseIds.map((id) => _bases[id]!).whereType<Base>().toList();
  }

  @override
  Future<BaseMember> addMember({required String baseId, required String userId, required BaseRole role}) async {
    final member = BaseMember(
      id: 'member_${_members.length + 1}',
      baseId: baseId,
      userId: userId,
      role: role,
      joinedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _members[baseId] = [...(_members[baseId] ?? []), member];
    
    // Add to user's bases
    _userBases[userId] = [...(_userBases[userId] ?? []), baseId];
    
    // Update base memberIds
    final base = _bases[baseId];
    if (base != null) {
      _bases[baseId] = base.copyWith(
        memberIds: [...base.memberIds, userId],
        updatedAt: DateTime.now(),
      );
    }
    
    return member;
  }

  @override
  Future<void> removeMember({required String baseId, required String userId}) async {
    _members[baseId]?.removeWhere((member) => member.userId == userId);
    _userBases[userId]?.remove(baseId);
    
    // Update base memberIds
    final base = _bases[baseId];
    if (base != null) {
      _bases[baseId] = base.copyWith(
        memberIds: base.memberIds.where((id) => id != userId).toList(),
        updatedAt: DateTime.now(),
      );
    }
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
    final base = _bases[baseId];
    return base?.ownerUserId == userId;
  }

  @override
  Future<void> updateLastAccessed(String baseId) async {
    final base = _bases[baseId];
    if (base != null) {
      _bases[baseId] = base.copyWith(
        lastAccessedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
  }
}

void main() {
  group('SpBasesRepository', () {
    late SpBasesRepository repository;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      repository = SpBasesRepository();
    });

    tearDown(() async {
      await prefs.clear();
    });

    group('createBase', () {
      test('should create a base and add owner as member', () async {
        // Setup mock current user
        await prefs.setString('mb.currentUser', 'testuser');
        await prefs.setString('mb.users', '{"testuser": {"userId": "user_123", "nickname": "testuser"}}');

        final base = await repository.createBase(
          name: 'Test Base',
          description: 'A test base',
          userId: 'user_123',
        );

        expect(base.name, equals('Test Base'));
        expect(base.description, equals('A test base'));
        expect(base.ownerUserId, equals('user_123'));
        expect(base.memberIds, contains('user_123'));

        // Verify it's saved to storage
        final savedBases = await repository.listMyBases('user_123');
        expect(savedBases.length, equals(1));
        expect(savedBases.first.id, equals(base.id));
      });

      test('should create base with provided userId', () async {
        // Test that createBase works with explicit userId (no need for current user setup)
        final base = await repository.createBase(
          name: 'Test Base',
          userId: 'user_123',
        );
        
        expect(base.name, equals('Test Base'));
        expect(base.ownerUserId, equals('user_123'));
        expect(base.memberIds, contains('user_123'));
      });
    });

    group('listMyBases', () {
      test('should return empty list when user has no bases', () async {
        final bases = await repository.listMyBases('user_123');
        expect(bases, isEmpty);
      });

      test('should return user bases', () async {
        // Setup mock current user and create a base
        await prefs.setString('mb.currentUser', 'testuser');
        await prefs.setString('mb.users', '{"testuser": {"userId": "user_123", "nickname": "testuser"}}');
        
        await repository.createBase(name: 'Test Base 1', userId: 'user_123');
        await repository.createBase(name: 'Test Base 2', userId: 'user_123');

        final bases = await repository.listMyBases('user_123');
        expect(bases.length, equals(2));
        expect(bases.map((b) => b.name), containsAll(['Test Base 1', 'Test Base 2']));
      });
    });

    group('addMember', () {
      test('should add member to base', () async {
        // Setup and create base
        await prefs.setString('mb.currentUser', 'testuser');
        await prefs.setString('mb.users', '{"testuser": {"userId": "user_123", "nickname": "testuser"}}');
        
        final base = await repository.createBase(name: 'Test Base', userId: 'user_123');

        final member = await repository.addMember(
          baseId: base.id,
          userId: 'user_456',
          role: BaseRole.member,
        );

        expect(member.userId, equals('user_456'));
        expect(member.role, equals(BaseRole.member));
        expect(member.baseId, equals(base.id));

        // Verify member is added to base
        final members = await repository.listMembers(base.id);
        expect(members.length, equals(2)); // Owner + new member
        expect(members.any((m) => m.userId == 'user_456'), isTrue);
      });
    });

    group('isOwner', () {
      test('should return true for base owner', () async {
        await prefs.setString('mb.currentUser', 'testuser');
        await prefs.setString('mb.users', '{"testuser": {"userId": "user_123", "nickname": "testuser"}}');
        
        final base = await repository.createBase(name: 'Test Base', userId: 'user_123');

        final isOwner = await repository.isOwner(baseId: base.id, userId: 'user_123');
        expect(isOwner, isTrue);
      });

      test('should return false for non-owner', () async {
        await prefs.setString('mb.currentUser', 'testuser');
        await prefs.setString('mb.users', '{"testuser": {"userId": "user_123", "nickname": "testuser"}}');
        
        final base = await repository.createBase(name: 'Test Base', userId: 'user_123');

        final isOwner = await repository.isOwner(baseId: base.id, userId: 'user_456');
        expect(isOwner, isFalse);
      });
    });
  });
}
