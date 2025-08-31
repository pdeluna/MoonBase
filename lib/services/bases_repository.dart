import 'package:moonbase_skeleton/models/base.dart';
import 'package:moonbase_skeleton/models/base_member.dart';
import 'package:moonbase_skeleton/models/enums.dart';

abstract class BasesRepository {
  Future<Base> createBase({required String name, String? description, String? avatarUrl});
  Future<void> deleteBase(String baseId);

  Future<Base?> getBase(String baseId);
  Future<List<Base>> listMyBases(String userId);

  Future<BaseMember> addMember({required String baseId, required String userId, required BaseRole role});
  Future<void> removeMember({required String baseId, required String userId});

  Future<List<BaseMember>> listMembers(String baseId);
  Future<void> upsert(Base base);
  
  /// Check if a user is the owner of a base
  Future<bool> isOwner({required String baseId, required String userId});
}