import 'package:mocktail/mocktail.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/bases/domain/repositories/base_repository.dart';

class MockBaseRepository extends Mock implements BaseRepository {}

class _BaseIdFake extends Fake implements BaseId {}

class _UserIdFake extends Fake implements UserId {}

/// Registers fallback values for ID types used by [MockBaseRepository] when
/// tests pass `any(named: ...)` for non-nullable [BaseId] / [UserId] params.
///
/// Call once per test file from `setUpAll`.
void registerBasesFallbacks() {
  registerFallbackValue(_BaseIdFake());
  registerFallbackValue(_UserIdFake());
}
