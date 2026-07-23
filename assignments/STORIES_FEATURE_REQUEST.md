# Feature Request: Stories (Instagram / Snapchat-style)

| Field | Value |
| --- | --- |
| **Ticket ID** | MB-P3-SLICE-B |
| **Maps to DoD** | [`PHASE3_DOD_ACTION_LIST.md`](../docs/PHASE3_DOD_ACTION_LIST.md) Section 2 (Slice B — Stories) + Section 3.2 (Reactions, scoped to story targets) |
| **Maps to Blueprint** | [`PHASE3_POSTS_STORIES_REACTIONS_BLUEPRINT.md`](../docs/PHASE3_POSTS_STORIES_REACTIONS_BLUEPRINT.md) Sections 2–4 |
| **Slice** | B (Stories). Slice C (Posts) is a sibling ticket that follows the same patterns. |
| **Learning milestone** | State management and architecture: `AsyncValue`-based unidirectional data flow, controller-vs-VM separation, repository pattern with cloud-ready ports, optimistic UI with rollback. |
| **Estimated effort** | 3–5 working days for an attentive junior with the blueprint as reference. |
| **Owner** | *Assigned junior contributor* |
| **Reviewer** | *Project maintainer* |

> **Read this entire document before opening any file.** Every section is load-bearing. The acceptance criteria in Section 4 and the self-review checklist in Section 5 are the gates between "I think it works" and "ready for review."

---

## Table of Contents

1. [Feature Overview & User Stories](#1-feature-overview--user-stories)
2. [Architectural Guardrails](#2-architectural-guardrails)
3. [End-to-End Requirements](#3-end-to-end-requirements)
4. [Acceptance Criteria (Definition of Done)](#4-acceptance-criteria-definition-of-done)
5. [Self-Review Checklist (Pre-PR)](#5-self-review-checklist-pre-pr)

---

## 1. Feature Overview & User Stories

### 1.1 Product summary

Members of a Base can publish a **Story**: a single image or short video, optionally captioned, that disappears after a configurable TTL (default 24h). Active stories appear as colored avatar bubbles at the top of the base home feed; tapping a bubble opens a full-screen viewer with timed progress bars that auto-advance through the author's stories. Other members can react with one of six emoji kinds. If the base owner has enabled it, expired stories archive to a per-base **Highlights** grid.

This is the canonical Instagram / Snapchat Stories interaction. The Phase 3 build is **local-only** (no server); the architecture is shaped so Phase 4 cloud sync is a one-file swap.

### 1.2 User stories

Written in the `As a … I want … So that …` form. Each story is testable; each maps to one or more acceptance criteria in Section 4.

#### Publishing

- **US-1.** As a base member, I want to tap the "+" bubble on my own avatar in the story strip and pick a photo or short video from my gallery or the OS camera, so that I can share a moment to my base.
- **US-2.** As a publisher, I want to add an optional caption (≤ 280 characters) before publishing, so that I can give context to my media.
- **US-3.** As a publisher, I want to see immediate confirmation that my story posted (bubble appears, viewer state updates), even before any persistence completes, so that the app feels responsive.
- **US-4.** As a publisher, I want to delete my own story at any time, so that I can retract content I no longer want shared.

#### Consuming

- **US-5.** As a base member, I want the story strip at the top of the home feed to show one bubble per author with active (non-expired) stories, so that I can see who has posted recently.
- **US-6.** As a viewer, I want unviewed stories to be visually distinguished (colored ring) from viewed ones (gray ring), so that I can find new content at a glance.
- **US-7.** As a viewer, I want to tap a bubble to open the full-screen viewer, with a progress bar at the top filling proportionally as the story plays (≈ 5s per image, video duration for videos), so that I know how long is left.
- **US-8.** As a viewer, I want to tap the right edge to advance to the next story, tap the left edge to go back, and swipe down to dismiss, so that navigation matches the standard pattern from Instagram and Snapchat.
- **US-9.** As a viewer, I want to react with one of `like, heart, laugh, wow, sad, fire` via a chip row at the bottom of the viewer, with my current selection highlighted and counts visible, so that I can express a response.
- **US-10.** As a viewer, I want to react only once per story; tapping a different kind replaces my prior reaction, and tapping my current selection removes it, so that one-per-user is enforced.

#### Archive (owner-configured)

- **US-11.** As a base owner, I want to toggle "Stories archive" on/off in base settings and override the story TTL (presets: 6h / 24h / 72h), so that I can tune my base's culture.
- **US-12.** As a base member, when the archive is enabled, I want expired stories to appear in a per-base **Highlights** grid sorted by created-at descending, so that I can revisit older moments.
- **US-13.** As a base member, when the archive is disabled, I want expired stories to be hard-deleted (including their underlying media file) so that retention rules are honored.

#### Cross-cutting

- **US-14.** As a base member of multiple bases, I want stories from base A to never appear in base B, and switching bases to swap the story strip cleanly, so that base isolation is preserved.
- **US-15.** As any user, I want clear error states when the network or storage fails (with a retry affordance), and a clear empty state when there are no active stories, so that I am never staring at a blank screen.

### 1.3 Explicit non-goals (do not build any of these)

- A custom in-app camera with live preview, hold-to-record, filters, or overlays. Use `image_picker` with `ImageSource.camera` only. See [`PHASE3_DOD_ACTION_LIST.md`](../docs/PHASE3_DOD_ACTION_LIST.md) Scope row "Camera capture".
- Story-to-story DM replies, threaded comments, or @mentions.
- Push notifications when someone reacts to your story.
- Multiple media per story (the entity carries `MediaRef media`, singular — `maxMediaPerStory = 1` for MVP).
- Story stickers, polls, location tags, music overlays.
- Cross-base "discover" feeds. Stories are strictly per-base.
- Server-side anything. Phase 3 is local-only.

---

## 2. Architectural Guardrails

These are **non-negotiable**. They re-state the rules established in [`PHASE3_POSTS_STORIES_REACTIONS_BLUEPRINT.md`](../docs/PHASE3_POSTS_STORIES_REACTIONS_BLUEPRINT.md) Sections 2–3 and [`REFACTOR_ARCHITECTURE.md`](../docs/phase2/REFACTOR_ARCHITECTURE.md). A PR that violates any of them will be rejected with a code-change request.

### 2.1 Unidirectional data flow (UDF)

**Events flow down. State flows up. Never the reverse.**

- Widgets emit **intents** (method calls on a controller). Widgets never mutate state directly.
- Controllers translate intents into use-case calls. Controllers do not write to data sources directly.
- Use cases validate inputs and call repositories.
- Repositories own data sources and `MediaStorage`.
- Data sources emit `Stream<List<Model>>`. Repositories project that into `Stream<List<Entity>>`.
- Controllers publish `AsyncValue<...>`. ViewModels project that into screen-shaped props. Widgets read props.

Every list-bearing screen exposes exactly one piece of state shaped as `AsyncValue<List<Entity>>`. Loading, success, and error are not three different fields; they are three constructors of one `AsyncValue`.

> **The canonical reference** is the existing chat feature. When in doubt, mirror it:
>
> - [`lib/features/chat/presentation/controllers/chat_controller.dart`](../lib/features/chat/presentation/controllers/chat_controller.dart) — `AsyncValue<List<Message>>` + stream subscription.
> - [`lib/features/chat/data/repositories/chat_repository_impl.dart`](../lib/features/chat/data/repositories/chat_repository_impl.dart) — `{required local, this.remote}` shape.
> - [`lib/features/chat/presentation/viewmodels/chat_screen_vm.dart`](../lib/features/chat/presentation/viewmodels/chat_screen_vm.dart) + [`chat_screen_vm_provider.dart`](../lib/features/chat/presentation/providers/chat_screen_vm_provider.dart) — VM as derived `Provider`.
>
> If your implementation does not match the shape of these files, you are off the path. Stop and re-read the blueprint.

### 2.2 Local state vs global app state — the partition

This is the single concept most often confused by junior developers on Riverpod projects. Memorize the partition below.

**Local state** lives in `StatefulWidget.State` or a `useState`-style hook. It is **ephemeral**, **per-widget**, **never persisted**, and **never read by another widget**. Examples in this feature:

- The `TextEditingController` for the caption input in `StoryCaptureScreen`.
- The `VideoPlayerController` instance inside a single `StoryViewerSlide`.
- The animation `AnimationController` for the story progress bar.
- The "is the swipe-down gesture currently dragging?" flag inside `StoryViewerScreen`.
- The currently focused index of the story being viewed *within a single viewer session* (it resets when the viewer closes).

**Global app state** lives in a Riverpod `Provider` / `StateNotifier`. It is **shared across widgets**, **may be persisted**, and is **the source of truth** for cross-screen invariants. Examples in this feature:

- The list of active stories per base (`StoryFeedController`).
- The current user's reaction on each story (`ReactionController`).
- The base's `BaseSettings` (TTL, archive enabled).
- The selected base (`effectiveSelectedBaseProvider`, already exists).
- The current authenticated user (`currentUserProvider`, already exists).

**Partition rules:**

| Question | If yes → it's | If no → it's |
| --- | --- | --- |
| Does another widget on another screen need to read this? | Global | Local |
| Does it survive widget rebuild without loss? | Global | Local |
| Is it persisted across app launches? | Global (necessarily) | Local |
| Does it represent a domain entity (Story, Reaction, BaseSettings)? | Global | Local |
| Is it a UI affordance (focus, animation tween, hover, ephemeral drag offset)? | Local | Global |

> **Guardrail:** if you find yourself reaching for `setState` to update something that another screen will also need to see, **stop**. Promote it to a controller or provider. Conversely, if you create a `Provider` to hold a `TextEditingController`, you are over-engineering — keep that local.

### 2.3 Dumb tiles

Leaf widgets (`StoryBubble`, `StoryProgressBar`, `ReactionChip`, `MediaTile`) take **props** and emit **intents via callbacks**. They do **not** call `ref.watch` or `ref.read` themselves.

**The one exception** is `MediaTile`'s read of `mediaStorageProvider` — that is acceptable infrastructure because URI resolution is platform-dependent. No other leaf widget gets to read providers. This is constraint #3 of the Phase 3 DoD.

### 2.4 Failures are values, not exceptions

Use cases and repositories return `Either<Failure, T>` ([`lib/core/either.dart`](../lib/core/either.dart)). Only the **controller** is allowed to translate a `Left(Failure)` into an `AsyncValue.error`. Widgets never see a `Failure` object; they see an `AsyncValue` and render via `.when(...)`.

Throwing from a use case or repository is a bug. Wrap all I/O in `guard(...)` from [`lib/core/error_mapper.dart`](../lib/core/error_mapper.dart), exactly as `ChatRepositoryImpl` does:

```17:22:moonbase_skeleton/lib/features/chat/data/repositories/chat_repository_impl.dart
  Future<Either<Failure, Message>> sendMessage({required BaseId baseId, required UserId userId, required String content}) =>
    guard(() async {
      final m = await local.sendMessage(baseId: baseId.value, userId: userId.value, content: content);
      return m.toEntity();
    });
```

### 2.5 Base isolation by construction

Every persistence key for this feature must be prefixed with `baseId`:

- `mb.stories.<baseId>` — story list per base.
- `mb.reactions.story.<storyId>` — reactions on a story.
- `mb.baseSettings.<baseId>` — settings per base.
- `<baseId>/<uuid>.<ext>` — media storage key (relative, content-addressable).

There is **no** global "all stories" key. If you need to enumerate stories across bases (e.g. the expiry sweep), iterate over the user's membership list and read per-base keys. This is non-negotiable; a single global key would be a privacy bug.

### 2.6 Cloud-ready ports (Phase 4)

Every repository follows `{required local, this.remote}`. `remote` is **null** in Phase 3 and your code must function correctly with `remote == null`. The abstract `StoryRemoteDataSource` exists only so Phase 4 can implement it without changing call sites.

Do not import `dart:io`, `path_provider`, `shared_preferences`, or `image_picker` from anywhere under `lib/features/stories/domain/` or `lib/features/stories/presentation/`. Those imports live in `data/datasources/` only.

---

## 3. End-to-End Requirements

This section translates the user stories into concrete artifacts. Treat it as your build order from top to bottom.

> **Riverpod ⇄ Redux translation** (in case you've previously worked in a Redux codebase):
>
> | Redux concept | Riverpod / this project equivalent |
> | --- | --- |
> | Action / mutation | A method on a `StateNotifier` controller (e.g. `StoryFeedController.publish(...)`) that calls a use case |
> | Reducer | The `state = state.copyWith(...)` inside a controller method |
> | Selector | A derived `Provider` (the ViewModel, e.g. `storyViewerVmProvider`) |
> | Thunk / middleware / side-effect | The use case + repository call inside the controller method — async work happens here, not in the reducer |
> | Store | The Riverpod `ProviderScope` set up in [`lib/main.dart`](../lib/main.dart) |

### 3.1 UI / View layer

#### 3.1.1 Files to create (under `lib/features/stories/presentation/`)

| Path | Type | Responsibility |
| --- | --- | --- |
| `screens/story_capture_screen.dart` | `ConsumerStatefulWidget` | Pick → caption → publish flow. Owns local state for the caption `TextEditingController` and the picked `MediaRef`. Calls `StoryFeedController.publish(...)`. |
| `screens/story_viewer_screen.dart` | `ConsumerStatefulWidget` | Full-screen viewer with progress bars, tap-edge navigation, swipe-down dismiss. Local state for `PageController`, current author index, current story-within-author index, `AnimationController` for the progress bar. |
| `screens/story_archive_screen.dart` | `ConsumerWidget` | Grid of archived stories, sorted desc. Gated on `BaseSettings.storiesArchiveEnabled`; shows a "Highlights are disabled" empty state otherwise. |
| `widgets/story_bubbles_strip.dart` | `ConsumerWidget` | Horizontal scrollable strip; one bubble per author with active stories + the "+" bubble for current user. Renders from a VM, not directly from controller state. |
| `widgets/story_bubble.dart` | `StatelessWidget` | Single avatar with colored/gray ring (unviewed/viewed) and optional plus-icon overlay. **Dumb tile.** |
| `widgets/story_progress_bar.dart` | `StatelessWidget` | One segment per story in the current author's set; the active segment animates from 0 → 1 over the story's duration. Takes a `progress` double (0..1) and a `segmentCount` int. **Dumb tile.** |
| `widgets/reaction_chip_row.dart` | `ConsumerWidget` (acceptable: it reads a small VM) | Renders the 6-kind chip row with counts; highlights the user's current selection. Emits `onReact(ReactionKind)` and `onUnreact()` callbacks. |

#### 3.1.2 Rendering rules

- **Story bubbles strip** sits at the top of the base home feed, above the (future) post list. Replace the placeholder `_FeedPage` cards in [`lib/legacy/screens/home_screen.dart`](../lib/legacy/screens/home_screen.dart) per [`PHASE3_DOD_ACTION_LIST.md`](../docs/PHASE3_DOD_ACTION_LIST.md) Section 2.2.7.
- **Bubble order**: current user first (always, whether they have stories or not — their bubble carries the "+" affordance); then other authors sorted by their most-recent story's `createdAt` descending.
- **Ring color**: unviewed → vivid colored gradient ring (Material primary); all-viewed → muted grey ring. "Viewed" is tracked per `(viewerUserId, storyId)`. For Phase 3 you may persist viewed-state in a local `mb.storyViews.<baseId>` map (gitignored by spec — it's a UI concern, not a domain entity).
- **Progress bar**: an `AnimationController` runs from 0..1 over `story.media.duration ?? 5s`. On completion, advance to the next story in the author's set. On exhausting the set, advance to the next author. On exhausting all authors, close the viewer.
- **Gestures** in `StoryViewerScreen` (in priority order — first match wins):
  1. **Vertical drag down ≥ 80px** → dismiss (`Navigator.pop`).
  2. **Long-press** → pause the progress animation; release → resume.
  3. **Tap on the right ⅔ of the screen** → next story.
  4. **Tap on the left ⅓ of the screen** → previous story (or previous author if at the first).
- **Loading states** during the viewer:
  - Image not yet decoded → show a centered `MoonSpinner` overlay; **pause** the progress controller until first frame.
  - Video buffering → same; resume only after `VideoPlayerController.value.isInitialized && !buffering`.
- **Caption** overlays at the bottom 1/6 of the viewer, with a translucent black gradient behind it for legibility.

#### 3.1.3 Per-screen ViewModels (must be derived `Provider`s)

| Provider | Returns | Reads |
| --- | --- | --- |
| `storyBubblesStripVmProvider` | `StoryBubblesStripVM { List<StoryAuthorBubble> authors; bool canPublish; }` | `storyFeedControllerProvider`, `currentUserProvider`, `effectiveSelectedBaseProvider`, `storyViewsProvider` |
| `storyCaptureVmProvider` | `StoryCaptureVM { MediaRef? picked; int captionLength; bool canPublish; AsyncValue<void> publishing; }` | `storyFeedControllerProvider`, screen-local picked state |
| `storyViewerVmProvider.family<StoryViewerVM, UserId>` | `StoryViewerVM { List<Story> authorStories; int initialIndex; }` | `storyFeedControllerProvider`, `effectiveSelectedBaseProvider` |
| `storyArchiveVmProvider` | `StoryArchiveVM { AsyncValue<List<Story>> archive; bool archiveEnabled; }` | `storyFeedControllerProvider`, `baseSettingsControllerProvider` |
| `storyReactionsVmProvider.family<StoryReactionsVM, StoryId>` | `StoryReactionsVM { Map<ReactionKind,int> counts; ReactionKind? mine; bool isLoading; }` | `reactionControllerProvider`, `currentUserProvider` |

ViewModels are **pure functions of upstream providers**. They are `Provider`, never `StateNotifierProvider`. If you find yourself wanting a `StateNotifier` for a VM, the state belongs in the upstream controller instead.

### 3.2 State management layer

> **Translation reminder:** in this codebase "actions/mutations" are **controller methods**, "reducers" are the `state = state.copyWith(...)` calls inside them, "selectors" are **derived providers (VMs)**, and "side-effects/middleware" are **use case + repository calls inside the controller methods**.

#### 3.2.1 Controllers (under `lib/features/stories/presentation/controllers/`)

##### `StoryFeedController extends StateNotifier<StoryFeedState>`

```dart
class StoryFeedState {
  const StoryFeedState({
    this.active = const AsyncValue.data([]),
    this.archive = const AsyncValue.data([]),
    this.publishing = const AsyncValue.data(null),
  });
  final AsyncValue<List<Story>> active;
  final AsyncValue<List<Story>> archive;
  final AsyncValue<void> publishing;
  StoryFeedState copyWith({ /* ... */ });
}
```

**Mutations (controller methods):**

| Method | Side effect (use case) | State transitions |
| --- | --- | --- |
| `load(BaseId)` | `ListActiveStories`, `ListArchivedStories`, then subscribe to `StreamActiveStories` | `active = loading` → `active = data(list)` or `active = error(failure)`; `archive` similarly |
| `publish({MediaRef media, String? caption})` | `PublishStory` | `publishing = loading` → `publishing = data(null)` (and the stream tick updates `active`); on failure → `publishing = error(failure)` |
| `delete(StoryId)` | `DeleteStory` | Stream tick re-emits without the deleted row; on failure → surface via a transient error provider |
| `sweepExpired(BaseId)` | `ExpireAndArchiveStories` | Called on app start and on every `streamActive` tick by the repository, **not** the controller — the controller only calls it manually if it owns the responsibility per architecture choice; see Section 3.3 |

**Stream subscription pattern** (mirror chat exactly):

```44:59:moonbase_skeleton/lib/features/chat/presentation/controllers/chat_controller.dart
  Future<void> load(String baseId) async {
    _sub?.cancel();
    state = state.copyWith(messages: const AsyncValue.loading());

    final res = await _listMessages(ListMessagesParams(baseId: baseId.bid));
    state = res.match(
      (f) => state.copyWith(messages: AsyncValue.error(f, StackTrace.current)),
      (list) => state.copyWith(messages: AsyncValue.data(_newestFirst(list))),
    );

    developer.log('ChatController: Starting stream for base $baseId');
    _sub = _streamMessages(baseId.bid).listen((list) {
      developer.log('ChatController: Received ${list.length} messages from stream');
      state = state.copyWith(messages: AsyncValue.data(_newestFirst(list)));
    });
  }
```

Always `_sub?.cancel()` on entry to `load(...)` and in `dispose()`. Forgetting this leaks stream listeners on base switch.

##### `ReactionController extends StateNotifier<ReactionState>`

State is a `Map<EntityKey, AsyncValue<List<Reaction>>>` keyed by `(targetKind, entityId)`. Mutations:

| Method | Use case | Behavior |
| --- | --- | --- |
| `loadFor(targetKind, entityId)` | `ListReactionsFor` + subscribe to `StreamReactionsFor` | Standard load + stream pattern. |
| `react(targetKind, entityId, kind)` | `React` | **Optimistic update first**: mutate the in-memory map (replace the user's prior reaction or add a new one), publish the new `AsyncValue.data`. Then `await` the use case. On `Left(Failure)`: roll back to the prior list and publish a transient error. |
| `unreact(targetKind, entityId)` | `Unreact` | Same optimistic+rollback pattern. |

The optimistic UI sequence is the worked example in [`PHASE3_POSTS_STORIES_REACTIONS_BLUEPRINT.md`](../docs/PHASE3_POSTS_STORIES_REACTIONS_BLUEPRINT.md) Section 2.3. Re-read it before implementing.

##### `BaseSettingsController extends StateNotifier<AsyncValue<BaseSettings>>`

| Method | Use case | Behavior |
| --- | --- | --- |
| `load(BaseId)` | `GetBaseSettings` | Standard `AsyncValue` load. |
| `setArchiveEnabled(bool)` | `UpdateBaseSettings` (with role check) | On `Left(PermissionDeniedFailure)`: do not mutate state; surface the failure. |
| `setStoryTtl(Duration)` | `UpdateBaseSettings` | Same. |

#### 3.2.2 Use cases (under `lib/features/stories/domain/usecases/`)

| Use case | Params | Returns | Validation |
| --- | --- | --- | --- |
| `PublishStory` | `{ BaseId baseId, UserId authorUserId, MediaRef media, String? caption }` | `Either<Failure, Story>` | `caption == null \|\| caption.length <= 280`; read `BaseSettings` for current TTL; refuse if `!BaseSettings.storiesEnabled` |
| `ListActiveStories` | `BaseId` | `Either<Failure, List<Story>>` | None |
| `ListArchivedStories` | `BaseId` | `Either<Failure, List<Story>>` | Refuse with `PermissionDeniedFailure` if `!BaseSettings.storiesArchiveEnabled` |
| `StreamActiveStories` | `BaseId` | `Stream<List<Story>>` | None (the repo filters expired on every tick) |
| `DeleteStory` | `{ StoryId id, UserId actingUserId, BaseRole actingRole }` | `Either<Failure, Unit>` | Allowed iff `actingUserId == story.authorUserId \|\| actingRole.isOwnerOrAdmin` |
| `ExpireAndArchiveStories` | `BaseId` | `Either<Failure, Unit>` | Reads `BaseSettings`; archives if `storiesArchiveEnabled`, else hard-deletes + `MediaStorage.delete` |

Reaction use cases (`React`, `Unreact`, `ListReactionsFor`, `StreamReactionsFor`) live under `lib/features/posts/domain/usecases/` per the file tree in the "Recommended scaffolding" section of [`PHASE3_DOD_ACTION_LIST.md`](../docs/PHASE3_DOD_ACTION_LIST.md) — reactions are a narrow shared module used by both posts and stories.

> **Warning — do not catch and swallow:** every use case ends with a `repo.<method>(...)` call, the result of which is the use case's return value. Use cases do not contain `try/catch`. The repository's `guard(...)` wrapper is the **only** place exceptions become `Failure`s. If your use case has a `try` block, you are doing it wrong.

### 3.3 Networking / data layer

Phase 3 is local-only. "Networking" in this section means: the abstract `*RemoteDataSource` interface that Phase 4 will implement, plus the local `SharedPreferences` data source that ships today.

#### 3.3.1 Repository

```dart
// lib/features/stories/domain/repositories/story_repository.dart
abstract class StoryRepository {
  Future<Either<Failure, Story>> publishStory({
    required BaseId baseId,
    required UserId authorUserId,
    required MediaRef media,
    String? caption,
    required Duration ttl,
  });
  Stream<List<Story>> streamActive(BaseId baseId);
  Future<Either<Failure, List<Story>>> listActive(BaseId baseId);
  Future<Either<Failure, List<Story>>> listArchive(BaseId baseId);
  Future<Either<Failure, Unit>> deleteStory(StoryId id);
  Future<Either<Failure, Unit>> expireAndArchive(BaseId baseId);
}
```

Implementation shape mirrors `ChatRepositoryImpl`:

```dart
// lib/features/stories/data/repositories/story_repository_impl.dart
class StoryRepositoryImpl implements StoryRepository {
  StoryRepositoryImpl({
    required this.local,
    required this.media,
    required this.settings,
    this.remote,
  });

  final StoryLocalDataSource local;
  final StoryRemoteDataSource? remote; // null in Phase 3
  final MediaStorage media;             // for hard-delete on non-archived expiry
  final BaseSettingsRepository settings;

  // Each method: guard(...) wrapping a local call + entity conversion + (when archived)
  // settings lookup + MediaStorage.delete.
}
```

#### 3.3.2 Local data source

`StorySharedPrefsDataSource implements StoryLocalDataSource`, keyed by `mb.stories.<baseId>`. Mirror the pattern in [`lib/features/chat/data/datasources/chat_shared_prefs_data_source.dart`](../lib/features/chat/data/datasources/chat_shared_prefs_data_source.dart) — including the `StreamController.broadcast()` per-base map that emits on every write. The expiry sweep filters `isExpired` rows on each read and on each stream tick before emitting.

#### 3.3.3 Models (under `lib/features/stories/data/models/`)

`StoryModel` with `fromMap` / `toMap` / `toEntity`. JSON shape exactly matches the wire DTO in [`PHASE3_POSTS_STORIES_REACTIONS_BLUEPRINT.md`](../docs/PHASE3_POSTS_STORIES_REACTIONS_BLUEPRINT.md) Section 4.8. Backward-compat rule: missing fields default to safe values (`archived = false`, `syncStatus = synced`, `caption = null`).

#### 3.3.4 Phase 4 backend contract (for the abstract `StoryRemoteDataSource`)

The remote data source's method signatures must align with these endpoints — even though they are not implemented in this ticket, the **interface** must match:

| Method | Phase 4 endpoint | Body |
| --- | --- | --- |
| `publishStory(...)` | `POST /v1/bases/{baseId}/stories` | `{ id, mediaKey, caption?, ttlMs? }` |
| `listActive(baseId)` | `GET /v1/bases/{baseId}/stories?scope=active` | — |
| `listArchive(baseId)` | `GET /v1/bases/{baseId}/stories?scope=archive` | — |
| `streamActive(baseId)` | `WS /v1/realtime?baseId=...` filtered by `type: story.*` | — |
| `deleteStory(id)` | `DELETE /v1/bases/{baseId}/stories/{storyId}` | — |

See [`PHASE3_POSTS_STORIES_REACTIONS_BLUEPRINT.md`](../docs/PHASE3_POSTS_STORIES_REACTIONS_BLUEPRINT.md) Sections 4.3 and 4.7 for the full contract.

#### 3.3.5 Mock API simulation for testing

Tests must not hit `SharedPreferences` or the file system. Use `mocktail` (already in [`pubspec.yaml`](../pubspec.yaml) dev_dependencies):

- For controller tests: mock `StoryRepository`. Stub each method with `when(...).thenAnswer((_) async => Right(fakeStory))`. Use `fake_async` for TTL/expiry tests.
- For repository tests: use `SharedPreferences.setMockInitialValues({})` per the existing pattern in the "Testing Strategy" section of [`DEV_GUIDE.md`](../docs/DEV_GUIDE.md).
- For VM tests: override the upstream providers in a `ProviderContainer` and assert the VM output.
- For widget tests: pump the widget inside a `ProviderScope` with `storyFeedControllerProvider` and friends overridden to emit pre-canned `AsyncValue`s.

#### 3.3.6 Wiring in `main.dart`

Add the following to the existing overrides list in [`lib/main.dart`](../lib/main.dart):

```dart
storyRepositoryProvider.overrideWithValue(
  StoryRepositoryImpl(
    local: StorySharedPrefsDataSource(prefs),
    media: mediaStorage,
    settings: baseSettingsRepository,
  ),
),
reactionRepositoryProvider.overrideWithValue(
  ReactionRepositoryImpl(local: ReactionSharedPrefsDataSource(prefs)),
),
baseSettingsRepositoryProvider.overrideWithValue(
  BaseSettingsRepositoryImpl(local: BaseSettingsSharedPrefsDataSource(prefs)),
),
```

---

## 4. Acceptance Criteria (Definition of Done)

A reviewer will check every box below. If even one fails, the PR is sent back.

### 4.1 Functional acceptance

- [ ] **AC-1.** Tapping the "+" bubble opens `MediaPickerSheet` with four options (Camera Photo, Camera Video, Photo Library, Video Library). Each option calls the corresponding `MediaPicker` method and returns to the capture screen with the picked `MediaRef`.
- [ ] **AC-2.** The caption input enforces ≤ 280 characters; the publish button is disabled when `picked == null` or `caption.length > 280`.
- [ ] **AC-3.** Tapping publish writes the story to `SharedPreferences` under `mb.stories.<baseId>`, persists the media via `LocalFileMediaStorage`, and pops the capture screen. The new bubble appears in the strip without a manual refresh.
- [ ] **AC-4.** The story strip renders one bubble per author with active (non-expired) stories, plus a "+" bubble for the current user. Current user's bubble is first; remaining authors are sorted by most-recent-story descending.
- [ ] **AC-5.** Tapping a bubble opens `StoryViewerScreen` at that author's first unviewed story (or first story if all viewed).
- [ ] **AC-6.** The progress bar animates linearly over `story.media.duration ?? 5s`. On completion, advance to the next story; on author exhaustion, advance to next author; on full exhaustion, close the viewer.
- [ ] **AC-7.** Tap-right advances; tap-left rewinds (crossing author boundaries when at the first/last story). Long-press pauses; release resumes. Vertical drag down ≥ 80px dismisses.
- [ ] **AC-8.** Reaction chip row shows six chips (`like, heart, laugh, wow, sad, fire`) with current counts. Tapping a chip optimistically updates the UI; the stream reconciles on success; on `Left(Failure)` the optimistic change rolls back and a snackbar surfaces.
- [ ] **AC-9.** A user has at most one reaction per story; tapping a different kind replaces the prior reaction; tapping the current selection removes it.
- [ ] **AC-10.** Base owner can open base settings, toggle "Stories archive" on/off, and override TTL (presets 6h / 24h / 72h). Non-owners attempting `PATCH` receive `PermissionDeniedFailure` and the UI does not mutate.
- [ ] **AC-11.** Expired stories with `storiesArchiveEnabled = true` move to the archive on the next read/tick; with `storiesArchiveEnabled = false`, they are hard-deleted **and** `MediaStorage.delete(storageKey)` is invoked.
- [ ] **AC-12.** Story author or base owner/admin can delete a story. Any other user attempting to delete is rejected with `PermissionDeniedFailure`.
- [ ] **AC-13.** Stories from base A never appear when base B is selected. Switching bases swaps the entire story strip cleanly with one `AsyncValue.loading` flash.

### 4.2 Edge-case acceptance

- [ ] **AC-14. Network timeout (Phase 4 forward-compat).** Even with `remote == null` today, the repository methods must complete in ≤ 50ms p99 in local mode. When the Phase 4 stub is wired, a timeout from the remote must surface as `NetworkFailure` and **must not** corrupt local state.
- [ ] **AC-15. Empty active feed.** When no author has an active story, the strip shows only the current user's "+" bubble and a tappable hint ("Be the first to share."). No spinner, no error.
- [ ] **AC-16. Empty archive.** When `storiesArchiveEnabled = true` and there are no archived stories, `StoryArchiveScreen` shows a non-error empty-state ("No highlights yet").
- [ ] **AC-17. Archive disabled.** When `storiesArchiveEnabled = false`, `StoryArchiveScreen` shows a "Highlights are disabled for this base" state. The screen is reachable but never lists rows.
- [ ] **AC-18. Image decode failure.** If `MediaTile` cannot decode an image (corrupt bytes, missing file), the viewer **pauses** the progress controller, shows a centered "Can't load this story" placeholder with a "Skip" button, and on tap of Skip advances to the next story. The story is not deleted.
- [ ] **AC-19. Video buffering / playback failure.** If `VideoPlayerController` fails to initialize, behave per AC-18. If it initializes but stalls mid-playback, pause the progress bar and resume when buffering clears.
- [ ] **AC-20. Permission denied (camera/photos).** Denying the OS permission surfaces `PermissionDeniedFailure` (see [`lib/core/failure.dart`](../lib/core/failure.dart)) in a snackbar with an "Open Settings" action that calls `AppSettings.openAppSettings()` (or the platform equivalent).
- [ ] **AC-21. Oversized media.** Picking an image > 10 MB or a video > 50 MB / > 30 s surfaces `MediaTooLargeFailure` or `MediaTooLongFailure` (defined in [`lib/core/failure.dart`](../lib/core/failure.dart)). The story is **not** published.
- [ ] **AC-22. App restart re-resolves media.** After publishing, killing the app, and relaunching, the story bubble and viewer media re-render correctly. This proves `storageKey` is a relative key resolved through `MediaStorage`, not an absolute path.
- [ ] **AC-23. Concurrent publish then immediate close.** Pressing publish and immediately backing out of the capture screen does not orphan media on disk (success path completes; on failure the partial file is cleaned by `MediaStorage.delete`).
- [ ] **AC-24. Clock skew on expiry.** Advancing the device clock past `createdAt + ttl` makes the story disappear from the active feed on the next stream tick; rolling the clock backward does **not** revive an archived story.

### 4.3 Quality-bar acceptance

- [ ] **AC-25.** `fvm dart format --set-exit-if-changed .` is clean.
- [ ] **AC-26.** `fvm flutter analyze` reports zero warnings on `lib/` and `test/`.
- [ ] **AC-27.** `fvm flutter test` passes; coverage for `lib/features/stories/` ≥ 80% (matching the Phase 2 bar from [`README.md`](../README.md)).
- [ ] **AC-28.** No `print()` calls in production code (`avoid_print` is enabled in [`analysis_options.yaml`](../analysis_options.yaml)). Use `dart:developer` `log()` as the chat controller does.
- [ ] **AC-29.** No new direct imports from `lib/legacy/`. New code lives entirely under `lib/features/stories/` and additions to `lib/features/bases/`.
- [ ] **AC-30.** Every entity carrying media has a `syncStatus` field defaulted to `SyncStatus.synced`. Every `MediaRef.storageKey` is the relative form `<baseId>/<uuid>.<ext>`.

---

## 5. Self-Review Checklist (Pre-PR)

Before you mark your PR ready for review, walk through this five-point list with the **Files changed** tab open in front of you. If any point is uncertain, fix it before the reviewer sees it.

### 5.1 State mutation discipline

> **Check:** every state change in `StoryFeedController`, `ReactionController`, and `BaseSettingsController` happens through a single `state = state.copyWith(...)` call inside a controller method that itself returns from a `Future<Either<Failure, T>>` use case via `res.match(...)`. There is **no** mutation of `state` from outside a controller. There is **no** `try/catch` inside a use case. There is **no** `throw` inside a repository (only `guard(...)` boundaries).

Specifically grep your own diff for these red flags:

- `state.<field> =` (direct field assignment outside `copyWith` — almost always wrong).
- `setState(()` inside any `*Controller` (controllers are not widgets).
- `await prefs.` outside `lib/features/stories/data/datasources/` (data leakage across layers).
- `ref.read(...)` or `ref.watch(...)` inside a leaf widget under `lib/features/stories/presentation/widgets/` other than `mediaStorageProvider` (see Section 2.3).

### 5.2 Local vs global state partition

> **Check:** for every piece of state you added, you can answer "why is this `setState` / why is this a `Provider`?" using the table in Section 2.2. Specifically:
>
> - Your `TextEditingController`, `AnimationController`, and `PageController` instances are **local** to a `State` class and are disposed in `dispose()`.
> - Your story list, reaction map, viewed-set, and `BaseSettings` are **global** providers and are not duplicated as local fields.
> - You do **not** hold a `Provider<TextEditingController>` anywhere.
> - You do **not** hold a `StateNotifier` whose only state is a UI animation value.

### 5.3 UDF direction

> **Check:** trace one user intent (tap publish, tap react, tap delete) from widget callback → controller method → use case → repository → data source → stream → controller `state =` → VM → widget rebuild. The arrows go one way. There is no widget that reads from another widget's local state via a global key. There is no controller that calls another controller's mutation. There is no data source that publishes to a controller directly.

### 5.4 Failure handling at the boundary

> **Check:** for each use-case-returning call site in your controllers, you have a `res.match((failure) => …, (value) => …)` block. The failure branch publishes `AsyncValue.error(failure, stackTrace)` (or rolls back an optimistic update). No widget receives a raw `Failure`. No use case throws. Every repository method body is wrapped in `guard(...)`.

### 5.5 Cloud-ready and base-isolated

> **Check:**
>
> - Every repository constructor is `{required local, this.remote}` (or its specialized form with `media` / `settings` injected).
> - You can grep your diff for `mb.stories`, `mb.reactions`, `mb.baseSettings` and **every** match is prefixed with a `<baseId>` or `<storyId>` segment immediately after the static key.
> - You can grep for `MediaRef(storageKey:` and **every** value is `<baseId>/<uuid>.<ext>` form, not an absolute path.
> - Phase 4 cloud sync would require changing only `lib/main.dart` (provide a non-null `remote`). No other file in your diff would need to change.

---

## Appendix A — File checklist (use as a build order)

Tick off as you go. The order is dependency-first.

**Domain (no Flutter imports):**

- [ ] `lib/features/bases/domain/entities/base_settings.dart`
- [ ] `lib/features/bases/domain/repositories/base_settings_repository.dart`
- [ ] `lib/features/bases/domain/usecases/get_base_settings.dart`
- [ ] `lib/features/bases/domain/usecases/update_base_settings.dart`
- [ ] `lib/features/stories/domain/entities/story.dart`
- [ ] `lib/features/stories/domain/repositories/story_repository.dart`
- [ ] `lib/features/stories/domain/usecases/{publish_story,list_active_stories,list_archived_stories,stream_active_stories,delete_story,expire_and_archive_stories}.dart`
- [ ] `lib/features/posts/domain/entities/reaction.dart` (shared)
- [ ] `lib/features/posts/domain/repositories/reaction_repository.dart` (shared)
- [ ] `lib/features/posts/domain/usecases/{react,unreact,list_reactions_for,stream_reactions_for}.dart`

**Data:**

- [ ] `lib/features/bases/data/{datasources/base_settings_shared_prefs_data_source.dart, repositories/base_settings_repository_impl.dart}`
- [ ] `lib/features/stories/data/{models/story_model.dart, datasources/{story_local_data_source.dart, story_shared_prefs_data_source.dart, story_remote_data_source.dart}, repositories/story_repository_impl.dart}`
- [ ] `lib/features/posts/data/{models/reaction_model.dart, datasources/{reaction_local_data_source.dart, reaction_shared_prefs_data_source.dart, reaction_remote_data_source.dart}, repositories/reaction_repository_impl.dart}`

**Presentation:**

- [ ] `lib/features/stories/presentation/providers/story_providers.dart` (repo + use case providers)
- [ ] `lib/features/stories/presentation/controllers/story_feed_controller.dart`
- [ ] `lib/features/stories/presentation/controllers/reaction_controller.dart` (or under `posts/`)
- [ ] `lib/features/bases/presentation/controllers/base_settings_controller.dart`
- [ ] `lib/features/stories/presentation/viewmodels/{story_bubbles_strip_vm.dart, story_capture_vm.dart, story_viewer_vm.dart, story_archive_vm.dart, story_reactions_vm.dart}`
- [ ] `lib/features/stories/presentation/widgets/{story_bubble.dart, story_progress_bar.dart, story_bubbles_strip.dart, reaction_chip_row.dart}`
- [ ] `lib/features/stories/presentation/screens/{story_capture_screen.dart, story_viewer_screen.dart, story_archive_screen.dart}`
- [ ] `lib/features/bases/presentation/screens/base_settings_screen.dart`

**Wiring:**

- [ ] `lib/router.dart` — `/stories/capture`, `/stories/view/:authorId`, `/stories/archive`, `/bases/settings`.
- [ ] `lib/main.dart` — provider overrides per Section 3.3.6.
- [ ] `lib/legacy/screens/home_screen.dart` — mount `StoryBubblesStrip` at the top of the feed (per [`PHASE3_DOD_ACTION_LIST.md`](../docs/PHASE3_DOD_ACTION_LIST.md) Section 2.2.7).

**Tests** (one file per non-trivial unit):

- [ ] `test/features/stories/domain/usecases/*_test.dart`
- [ ] `test/features/stories/data/datasources/story_shared_prefs_data_source_test.dart`
- [ ] `test/features/stories/data/repositories/story_repository_impl_test.dart`
- [ ] `test/features/stories/presentation/controllers/story_feed_controller_test.dart` (includes `fake_async` expiry tests)
- [ ] `test/features/stories/presentation/controllers/reaction_controller_test.dart` (includes optimistic rollback test)
- [ ] `test/features/stories/presentation/viewmodels/*_test.dart`
- [ ] `test/features/stories/presentation/widgets/{story_bubble,story_progress_bar,reaction_chip_row}_test.dart`
- [ ] `test/features/bases/domain/usecases/{get_base_settings,update_base_settings}_test.dart` (includes role-check tests)

---

## Appendix B — References

- [`docs/PHASE3_DOD_ACTION_LIST.md`](../docs/PHASE3_DOD_ACTION_LIST.md) — slice-level checklist; Section 2 (Slice B) is the parent of this ticket.
- [`docs/PHASE3_POSTS_STORIES_REACTIONS_BLUEPRINT.md`](../docs/PHASE3_POSTS_STORIES_REACTIONS_BLUEPRINT.md) — architectural blueprint; cite section numbers in your PR.
- [`docs/phase2/REFACTOR_ARCHITECTURE.md`](../docs/phase2/REFACTOR_ARCHITECTURE.md) — 3-layer architecture overview.
- [`docs/DEVELOPMENT_SETUP.md`](../docs/DEVELOPMENT_SETUP.md) — toolchain, lint config, git workflow.
- [`docs/DEV_GUIDE.md`](../docs/DEV_GUIDE.md) — testing strategy and JSON-encoding gotchas.
- Canonical exemplar feature: [`lib/features/chat/`](../lib/features/chat/) — when in doubt, mirror its shape.

---

*Ticket MB-P3-SLICE-B. Created 2026-06-12. When complete, mark Phase 3 Slice B as ✅ in [`docs/MODEL_ARCHITECTURE.md`](../docs/MODEL_ARCHITECTURE.md) and tick the corresponding rows in [`docs/PHASE3_DOD_ACTION_LIST.md`](../docs/PHASE3_DOD_ACTION_LIST.md) Section 2 in the PR description.*
