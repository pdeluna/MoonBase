import 'package:mocktail/mocktail.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';
import 'package:moonbase_skeleton/features/stories/domain/repositories/story_repository.dart';

/// Shared test doubles for the Stories *domain* layer.
///
/// Pair-review notes (read this file with the junior before the test file):
///
/// 1. We mock [StoryRepository] — the **port** — not a Firebase/SharedPreferences
///    impl. `PublishStory` only knows the abstract class. If this test needed a
///    real backend, the layering would already be wrong.
/// 2. [Mock] vs [Fake]:
///    - [MockStoryRepository] records calls (`when` / `verify` / `verifyNever`).
///    - The `_…Fake` classes below are **not** collaborators. They exist only
///      because mocktail's `any(named: …)` matcher needs a dummy instance of
///      each non-nullable custom type. Nobody in the use case ever reads them.
/// 3. Call [registerStoriesFallbacks] once per test file from `setUpAll`.
///    Forgetting this fails at **runtime** with a confusing mocktail error, not
///    at compile time.
///
/// Mirror of `mocks_auth.dart` / `mocks_bases.dart` / `mocks_profile.dart`.
class MockStoryRepository extends Mock implements StoryRepository {}

class _BaseIdFake extends Fake implements BaseId {}

class _UserIdFake extends Fake implements UserId {}

class _MediaRefFake extends Fake implements MediaRef {}

/// Registers fallback values for named args on [MockStoryRepository.publishStory]
/// (`baseId`, `authorUserId`, `media`, `ttl`).
///
/// `caption` is `String?` — mocktail already knows `String` / `null`, so it
/// does not need a fallback.
void registerStoriesFallbacks() {
  registerFallbackValue(_BaseIdFake());
  registerFallbackValue(_UserIdFake());
  registerFallbackValue(_MediaRefFake());
  registerFallbackValue(Duration.zero);
}
