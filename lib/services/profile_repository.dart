import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moonbase_skeleton/models/profile.dart';

abstract class ProfileRepository {
  Future<Profile?> read();
  Future<void> write(Profile profile);
  Future<void> clear();
}

class SpProfileRepository implements ProfileRepository {
  static const _k = 'mb.profile';

  @override
  Future<Profile?> read() async {
    final sp = await SharedPreferences.getInstance();
    final s = sp.getString(_k);
    if (s == null) return null;
    try {
      debugPrint('SpProfileRepository READ profile JSON: $s');
      final map = jsonDecode(s) as Map<String, dynamic>;
      final profile = Profile.fromJson(map);
      debugPrint('SpProfileRepository READ parsed profile: userId=${profile.userId}, nickname=${profile.nickname}');
      return profile;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(Profile p) async {
    final sp = await SharedPreferences.getInstance();
    final json = jsonEncode(p.toJson());
    debugPrint('SpProfileRepository WRITE profile JSON: $json');
    await sp.setString(_k, json);

  }

  @override
  Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    debugPrint('SpProfileRepository CLEAR profile at key=$_k');
    await sp.remove(_k);
  }
}
