# Stories — Starter Scaffold (Steps 1–5)

| Field | Value |
| --- | --- |
| **Audience** | Junior developer — **bootstrap only** for the first domain slice |
| **Prerequisite** | [`STORIES_FIRST_STEPS.md`](STORIES_FIRST_STEPS.md) Step 0 tracer bullet complete; `main` includes merged media polish (POL-1–4) |
| **Companion** | Reasoning + pitfalls → [`STORIES_FIRST_STEPS.md`](STORIES_FIRST_STEPS.md). Full worked solution → [`STORIES_FIRST_STEPS_REFERENCE.md`](STORIES_FIRST_STEPS_REFERENCE.md) |
| **Goal** | Seven files, domain-only, `fvm flutter analyze` clean — then push draft PR per Step 6 |

> **How to use this.** Create each file below in order. Type the code yourself if you can; use this doc when you need a structural starting point. After Step 5, stop adding widgets/data layers until the mentor reviews your draft PR.

---

## Branch setup

Already on `phase3-stories`:

```powershell
cd "c:\Users\pdelu\App Dev\MoonBase Skeleton\moonbase_skeleton"
git checkout phase3-stories
git pull origin phase3-stories
```

Cutting fresh from `main` (first time only):

```powershell
git checkout main
git pull origin main
git checkout -b phase3-stories
```

---

## Files to create (in order)

```
lib/features/bases/domain/entities/
  base_role.dart          ← Step 1
  base_settings.dart      ← Step 1

lib/features/stories/domain/entities/
  story.dart              ← Step 2

lib/features/stories/presentation/providers/
  story_providers.dart    ← Step 3

lib/features/stories/domain/repositories/
  story_repository.dart   ← Step 4

lib/features/stories/domain/usecases/
  publish_story.dart      ← Step 5

test/features/stories/domain/usecases/
  publish_story_test.dart ← Step 5
```

Verify after each step:

```powershell
fvm flutter analyze lib/features/bases/domain/entities/
fvm flutter analyze lib/features/stories/
fvm flutter test test/features/stories/
```

---

## Step 1 — `base_role.dart`

**Path:** `lib/features/bases/domain/entities/base_role.dart`

```dart
enum BaseRole {
  owner,
  admin,
  member;

  bool get isOwnerOrAdmin =>
      this == BaseRole.owner || this == BaseRole.admin;
}
```

No imports required.

---

## Step 1 — `base_settings.dart`

**Path:** `lib/features/bases/domain/entities/base_settings.dart`

```dart
import 'package:flutter/foundation.dart';
import 'package:moonbase_skeleton/core/ids.dart';

@immutable
class BaseSettings {
  const BaseSettings({
    required this.baseId,
    required this.updatedAt,
    required this.updatedByUserId,
    this.storiesEnabled = true,
    this.storiesArchiveEnabled = true,
    this.storyTtl = const Duration(hours: 24),
    this.maxMediaPerStory = 1,
  });

  final BaseId baseId;
  final bool storiesEnabled;
  final bool storiesArchiveEnabled;
  final Duration storyTtl;
  final int maxMediaPerStory;
  final DateTime updatedAt;
  final UserId updatedByUserId;

  BaseSettings copyWith({
    BaseId? baseId,
    bool? storiesEnabled,
    bool? storiesArchiveEnabled,
    Duration? storyTtl,
    int? maxMediaPerStory,
    DateTime? updatedAt,
    UserId? updatedByUserId,
  }) {
    return BaseSettings(
      baseId: baseId ?? this.baseId,
      storiesEnabled: storiesEnabled ?? this.storiesEnabled,
      storiesArchiveEnabled:
          storiesArchiveEnabled ?? this.storiesArchiveEnabled,
      storyTtl: storyTtl ?? this.storyTtl,
      maxMediaPerStory: maxMediaPerStory ?? this.maxMediaPerStory,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedByUserId: updatedByUserId ?? this.updatedByUserId,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BaseSettings &&
        other.baseId == baseId &&
        other.storiesEnabled == storiesEnabled &&
        other.storiesArchiveEnabled == storiesArchiveEnabled &&
        other.storyTtl == storyTtl &&
        other.maxMediaPerStory == maxMediaPerStory &&
        other.updatedAt == updatedAt &&
        other.updatedByUserId == updatedByUserId;
  }

  @override
  int get hashCode => Object.hash(
        baseId,
        storiesEnabled,
        storiesArchiveEnabled,
        storyTtl,
        maxMediaPerStory,
        updatedAt,
        updatedByUserId,
      );
}
```

---

## Step 2 — `story.dart`

**Path:** `lib/features/stories/domain/entities/story.dart`

```dart
import 'package:flutter/foundation.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/core/sync_status.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';

@immutable
class Story {
  const Story({
    required this.id,
    required this.baseId,
    required this.authorUserId,
    required this.media,
    required this.ttl,
    required this.createdAt,
    this.caption,
    this.archived = false,
    this.syncStatus = SyncStatus.synced,
  });

  final StoryId id;
  final BaseId baseId;
  final UserId authorUserId;
  final MediaRef media;
  final String? caption;
  final Duration ttl;
  final DateTime createdAt;
  final bool archived;
  final SyncStatus syncStatus;

  bool get isExpired => DateTime.now().isAfter(createdAt.add(ttl));

  Story copyWith({
    StoryId? id,
    BaseId? baseId,
    UserId? authorUserId,
    MediaRef? media,
    String? caption,
    Duration? ttl,
    DateTime? createdAt,
    bool? archived,
    SyncStatus? syncStatus,
  }) {
    return Story(
      id: id ?? this.id,
      baseId: baseId ?? this.baseId,
      authorUserId: authorUserId ?? this.authorUserId,
      media: media ?? this.media,
      caption: caption ?? this.caption,
      ttl: ttl ?? this.ttl,
      createdAt: createdAt ?? this.createdAt,
      archived: archived ?? this.archived,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Story &&
        other.id == id &&
        other.baseId == baseId &&
        other.authorUserId == authorUserId &&
        other.media == media &&
        other.caption == caption &&
        other.ttl == ttl &&
        other.createdAt == createdAt &&
        other.archived == archived &&
        other.syncStatus == syncStatus;
  }

  @override
  int get hashCode => Object.hash(
        id,
        baseId,
        authorUserId,
        media,
        caption,
        ttl,
        createdAt,
        archived,
        syncStatus,
      );
}
```

**Invariants:** `media` is **singular** (`MediaRef`, not `List`). `archived` and `isExpired` are orthogonal.

---

## Step 3 — `story_providers.dart`

**Path:** `lib/features/stories/presentation/providers/story_providers.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonbase_skeleton/features/stories/domain/repositories/story_repository.dart';

final storyRepositoryProvider = Provider<StoryRepository>((ref) {
  throw UnimplementedError(
    'Provide StoryRepository in app wiring (lib/main.dart).',
  );
});

// Add use case providers here as they land, e.g.:
//
// final publishStoryUseCaseProvider = Provider(
//   (ref) => PublishStory(ref.read(storyRepositoryProvider)),
// );
```

---

## Step 4 — `story_repository.dart`

**Path:** `lib/features/stories/domain/repositories/story_repository.dart`

```dart
import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';
import 'package:moonbase_skeleton/features/stories/domain/entities/story.dart';

abstract class StoryRepository {
  Future<Either<Failure, Story>> publishStory({
    required BaseId baseId,
    required UserId authorUserId,
    required MediaRef media,
    required Duration ttl,
    String? caption,
  });

  /// Active = not expired AND not archived. Repository filters on each tick.
  Stream<List<Story>> streamActive(BaseId baseId);

  Future<Either<Failure, List<Story>>> listActive(BaseId baseId);

  Future<Either<Failure, List<Story>>> listArchive(BaseId baseId);

  Future<Either<Failure, Unit>> deleteStory(StoryId id);

  /// Sweep expired rows; archive or delete per base settings.
  Future<Either<Failure, Unit>> expireAndArchive(BaseId baseId);
}
```

---

## Step 5 — `publish_story.dart`

**Path:** `lib/features/stories/domain/usecases/publish_story.dart`

```dart
import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/core/usecase.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base_settings.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';
import 'package:moonbase_skeleton/features/stories/domain/entities/story.dart';
import 'package:moonbase_skeleton/features/stories/domain/repositories/story_repository.dart';

class PublishStoryParams {
  const PublishStoryParams({
    required this.baseId,
    required this.authorUserId,
    required this.media,
    required this.settings,
    this.caption,
  });

  final BaseId baseId;
  final UserId authorUserId;
  final MediaRef media;
  final String? caption;

  /// Controller reads BaseSettings and passes it in — use cases do not
  /// reach across repositories.
  final BaseSettings settings;
}

class PublishStory implements UseCase<Story, PublishStoryParams> {
  const PublishStory(this.repo);

  final StoryRepository repo;

  static const int _maxCaptionLength = 280;

  @override
  Future<Either<Failure, Story>> call(PublishStoryParams p) async {
    if (!p.settings.storiesEnabled) {
      return const Left(
        ValidationFailure('Stories are disabled for this base.'),
      );
    }

    final caption = p.caption?.trim();
    if (caption != null && caption.length > _maxCaptionLength) {
      return const Left(
        ValidationFailure('Caption must be 280 characters or fewer.'),
      );
    }

    return repo.publishStory(
      baseId: p.baseId,
      authorUserId: p.authorUserId,
      media: p.media,
      ttl: p.settings.storyTtl,
      caption: (caption == null || caption.isEmpty) ? null : caption,
    );
  }
}
```

**Rules:** No `try`/`catch`. No Riverpod. No `SharedPreferences`.

---

## Step 5 — `publish_story_test.dart`

**Path:** `test/features/stories/domain/usecases/publish_story_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/core/sync_status.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base_settings.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_type.dart';
import 'package:moonbase_skeleton/features/stories/domain/entities/story.dart';
import 'package:moonbase_skeleton/features/stories/domain/repositories/story_repository.dart';
import 'package:moonbase_skeleton/features/stories/domain/usecases/publish_story.dart';

class _MockStoryRepository extends Mock implements StoryRepository {}

void main() {
  late _MockStoryRepository repo;
  late PublishStory useCase;

  const baseId = BaseId('b1');
  const userId = UserId('u1');
  const media = MediaRef(
    id: MediaId('m1'),
    type: MediaType.image,
    storageKey: 'b1/m1.jpg',
  );

  BaseSettings enabledSettings({bool storiesEnabled = true}) =>
      BaseSettings(
        baseId: baseId,
        updatedAt: DateTime(2026, 1, 1),
        updatedByUserId: userId,
        storiesEnabled: storiesEnabled,
      );

  Story publishedStory() => Story(
        id: const StoryId('s1'),
        baseId: baseId,
        authorUserId: userId,
        media: media,
        ttl: const Duration(hours: 24),
        createdAt: DateTime(2026, 1, 1),
        syncStatus: SyncStatus.synced,
      );

  setUp(() {
    repo = _MockStoryRepository();
    useCase = PublishStory(repo);
  });

  test('returns ValidationFailure when stories are disabled', () async {
    final result = await useCase(
      PublishStoryParams(
        baseId: baseId,
        authorUserId: userId,
        media: media,
        settings: enabledSettings(storiesEnabled: false),
      ),
    );

    expect(result, isA<Left<Failure, Story>>());
    verifyNever(() => repo.publishStory(
          baseId: any(named: 'baseId'),
          authorUserId: any(named: 'authorUserId'),
          media: any(named: 'media'),
          ttl: any(named: 'ttl'),
          caption: any(named: 'caption'),
        ));
  });

  test('forwards to repository when settings allow stories', () async {
    when(
      () => repo.publishStory(
        baseId: baseId,
        authorUserId: userId,
        media: media,
        ttl: any(named: 'ttl'),
        caption: any(named: 'caption'),
      ),
    ).thenAnswer((_) async => Right(publishedStory()));

    final result = await useCase(
      PublishStoryParams(
        baseId: baseId,
        authorUserId: userId,
        media: media,
        settings: enabledSettings(),
        caption: '  hello  ',
      ),
    );

    expect(result, isA<Right<Failure, Story>>());
    verify(
      () => repo.publishStory(
        baseId: baseId,
        authorUserId: userId,
        media: media,
        ttl: const Duration(hours: 24),
        caption: 'hello',
      ),
    ).called(1);
  });
}
```

Add to `setUpAll` if mocktail complains about fallback types:

```dart
setUpAll(() {
  registerFallbackValue(const BaseId(''));
  registerFallbackValue(const UserId(''));
  registerFallbackValue(const StoryId(''));
  registerFallbackValue(
    const MediaRef(
      id: MediaId('m'),
      type: MediaType.image,
      storageKey: 'k',
    ),
  );
});
```

---

## Step 6 — Draft PR (after analyze + test pass)

```powershell
git add lib/features/bases/domain/entities/
git add lib/features/stories/
git add test/features/stories/
git commit -m "feat(stories): domain scaffold — entities, port, PublishStory"
git push -u origin phase3-stories
gh pr create --draft --base main --head phase3-stories --title "feat(stories): domain scaffold (draft)"
```

---

## Do not touch yet

- Widgets / screens
- `SharedPreferences` data sources
- `main.dart` wiring (until `StoryRepositoryImpl` exists)
- Legacy `lib/legacy/models/base_settings.dart` (leave in place)

---

## Chat slice mirror map

| Chat | Stories (you) |
| --- | --- |
| `Message` | `Story` |
| `ChatRepository` | `StoryRepository` |
| `SendMessage` | `PublishStory` |
| `chat_providers.dart` | `story_providers.dart` |
| `ChatController` | *(later)* `StoryController` |

See [`CHAT_ARCHITECTURE_DEMO_GUIDE.md`](CHAT_ARCHITECTURE_DEMO_GUIDE.md) for the live trace demo.
