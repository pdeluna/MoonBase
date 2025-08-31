import 'package:flutter_test/flutter_test.dart';
import 'package:moonbase_skeleton/models/base.dart';
import 'package:moonbase_skeleton/models/base_member.dart';
import 'package:moonbase_skeleton/models/enums.dart';
import 'package:moonbase_skeleton/services/bases_repository.dart';

// Mock implementation for testing
class MockBasesRepository implements BasesRepository {
  final Map<String, Base> _bases = {};
  final Map<String, List<BaseMember>> _members = {};
  int _baseCounter = 0;
  int _memberCounter = 0;

  @override
  Future<Base> createBase({required String name, String? description, String? avatarUrl}) async {
    _baseCounter++;
    final base = Base(
      id: 'base-$_baseCounter',
      name: name,
      ownerUserId: 'test-owner-id', // In real implementation, this would be the current user
      description: description,
      avatarUrl: avatarUrl,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    _bases[base.id] = base;
    
    // Add owner as first member
    _memberCounter++;
    final ownerMember = BaseMember(
      id: 'member-$_memberCounter',
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
    _memberCounter++;
    final member = BaseMember(
      id: 'member-$_memberCounter',
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
  group('BasesRepository Tests', () {
    late MockBasesRepository repository;

    setUp(() {
      repository = MockBasesRepository();
    });

    tearDown(() {
      // Clear any state if needed
    });

    group('Create Base', () {
      test('should create base with required fields', () async {
        final base = await repository.createBase(name: 'Test Base');

        expect(base.name, 'Test Base');
        expect(base.ownerUserId, 'test-owner-id');
        expect(base.description, isNull);
        expect(base.avatarUrl, isNull);
        expect(base.id, isNotEmpty);
        expect(base.createdAt, isNotNull);
        expect(base.updatedAt, isNotNull);
      });

      test('should create base with all fields', () async {
        final base = await repository.createBase(
          name: 'Test Base',
          description: 'A test base description',
          avatarUrl: 'https://example.com/avatar.jpg',
        );

        expect(base.name, 'Test Base');
        expect(base.description, 'A test base description');
        expect(base.avatarUrl, 'https://example.com/avatar.jpg');
      });

      test('should add owner as first member when creating base', () async {
        final base = await repository.createBase(name: 'Test Base');
        final members = await repository.listMembers(base.id);

        expect(members, hasLength(1));
        expect(members.first.userId, base.ownerUserId);
        expect(members.first.role, BaseRole.owner);
      });
    });

    group('List Bases', () {
            test('should list bases owned by user', () async {
        // Create a fresh repository for this test
        final testRepository = MockBasesRepository();
        
        final base1 = await testRepository.createBase(name: 'Base 1');
        final base2 = await testRepository.createBase(name: 'Base 2');

        final myBases = await testRepository.listMyBases('test-owner-id');

        expect(myBases, hasLength(2));
        expect(myBases.any((base) => base.id == base1.id), isTrue);
        expect(myBases.any((base) => base.id == base2.id), isTrue);
      });

      test('should list bases where user is a member', () async {
        final base = await repository.createBase(name: 'Test Base');
        
        // Add another member
        await repository.addMember(
          baseId: base.id,
          userId: 'member-user-id',
          role: BaseRole.member,
        );

        final memberBases = await repository.listMyBases('member-user-id');

        expect(memberBases, hasLength(1));
        expect(memberBases.first.id, base.id);
      });

      test('should return empty list for user with no bases', () async {
        await repository.createBase(name: 'Test Base');

        final myBases = await repository.listMyBases('non-existent-user');

        expect(myBases, isEmpty);
      });
    });

    group('Owner Validation', () {
      test('should return true for base owner', () async {
        final base = await repository.createBase(name: 'Test Base');
        
        final isOwner = await repository.isOwner(
          baseId: base.id,
          userId: base.ownerUserId,
        );

        expect(isOwner, isTrue);
      });

      test('should return false for non-owner', () async {
        final base = await repository.createBase(name: 'Test Base');
        
        final isOwner = await repository.isOwner(
          baseId: base.id,
          userId: 'non-owner-id',
        );

        expect(isOwner, isFalse);
      });

      test('should return false for admin member', () async {
        final base = await repository.createBase(name: 'Test Base');
        
        // Add admin member
        await repository.addMember(
          baseId: base.id,
          userId: 'admin-user-id',
          role: BaseRole.admin,
        );

        final isOwner = await repository.isOwner(
          baseId: base.id,
          userId: 'admin-user-id',
        );

        expect(isOwner, isFalse);
      });

      test('should return false for regular member', () async {
        final base = await repository.createBase(name: 'Test Base');
        
        // Add regular member
        await repository.addMember(
          baseId: base.id,
          userId: 'member-user-id',
          role: BaseRole.member,
        );

        final isOwner = await repository.isOwner(
          baseId: base.id,
          userId: 'member-user-id',
        );

        expect(isOwner, isFalse);
      });
    });

    group('Base Operations', () {
      test('should get base by id', () async {
        final createdBase = await repository.createBase(name: 'Test Base');
        final retrievedBase = await repository.getBase(createdBase.id);

        expect(retrievedBase, isNotNull);
        expect(retrievedBase!.id, createdBase.id);
        expect(retrievedBase.name, createdBase.name);
      });

      test('should return null for non-existent base', () async {
        final base = await repository.getBase('non-existent-id');

        expect(base, isNull);
      });

      test('should delete base and its members', () async {
        final base = await repository.createBase(name: 'Test Base');
        
        // Add a member
        await repository.addMember(
          baseId: base.id,
          userId: 'member-id',
          role: BaseRole.member,
        );

        await repository.deleteBase(base.id);

        final retrievedBase = await repository.getBase(base.id);
        final members = await repository.listMembers(base.id);

        expect(retrievedBase, isNull);
        expect(members, isEmpty);
      });
    });
  });
}
