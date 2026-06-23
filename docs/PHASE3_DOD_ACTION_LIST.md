# Phase 3 DoD — Action List (with Testing)

**Status:** In progress. **Foundation (Section 0) and Slice A (chat media) are code-complete and Android device-verified** (2026-06-22). Slice B (Stories) and Slice C (Posts + Reactions) remain. See device sign-off notes under Sections 0 and 1; follow-up UX fixes are tracked in [`assignments/PHASE3_MEDIA_POLISH_TICKET.md`](../assignments/PHASE3_MEDIA_POLISH_TICKET.md).

---

## Scope (locked)


| Decision       | Choice                                                                                                                                                                                                                                                                                                                                                                                                                         |
| -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Storage        | Local-only via `MediaStorage` port; `RemoteMediaStorage` interface stubbed for Phase 4 cloud swap                                                                                                                                                                                                                                                                                                                              |
| Media types    | Images + short video clips (≤ 30s, ≤ 50 MB). No voice notes this phase                                                                                                                                                                                                                                                                                                                                                         |
| Camera capture | **In scope** via OS-mediated camera (`image_picker` with `ImageSource.camera`). Tapping "Camera" in the `MediaPickerSheet` opens the OS camera and returns a captured photo/video as a `MediaRef`. A **custom in-app camera surface** (live preview, hold-to-record, overlays) is **out of scope** for Phase 3; the `MediaPicker` port is shaped so a Phase 4 `InAppCameraMediaPicker` can drop in without changing call sites |
| Chat media     | Send/receive image + video attachments in existing chat                                                                                                                                                                                                                                                                                                                                                                        |
| Stories        | 24h ephemeral bubble feed + per-base "Highlights" archive                                                                                                                                                                                                                                                                                                                                                                      |
| Story config   | Per-base, owner-configurable: enable archive (on/off), TTL override (default 24h), max media per story                                                                                                                                                                                                                                                                                                                         |
| Posts          | Text + 0–10 media items, persistent in base feed                                                                                                                                                                                                                                                                                                                                                                               |
| Reactions      | Stories + Posts only (chat untouched). MVP set: 👍 ❤️ 😂 😮 😢 🔥                                                                                                                                                                                                                                                                                                                                                              |
| Sequencing     | Slice A: chat media → Slice B: stories → Slice C: posts + reactions                                                                                                                                                                                                                                                                                                                                                            |
| Out of scope   | Live streaming, voice notes, threaded replies, content moderation tooling, push notifications, in-app trim/edit, custom in-app camera surface (live preview, hold-to-record, overlays)                                                                                                                                                                                                                                         |


## Definition of Done (high level)

A Phase 3 build is "done" when:

1. A base member can attach an image or short video to a chat message and any other base member sees it.
2. A base member can publish a story; the bubble appears on the base home feed for ≤ 24h (or owner-configured TTL); after expiry the story is archived to "Highlights" if the base allows it; only mutual base members can ever see it.
3. A base member can create a post (text + up to 10 media); the post is rendered on the base home feed indefinitely.
4. A base member can react to a story or post; reaction counts and the user's own reaction are visible.
5. A base owner can open base settings and toggle "Stories archive" on/off and override the story TTL; settings persist and apply on next publish.
6. All persistence is local; no remote calls. All entities carrying media include a `syncStatus` field (default `synced` while local-only). Media URIs are content-addressable keys, not absolute device paths.
7. Full unit test suite passes (`flutter test`). Manual smoke covers each slice's flows + base-isolation invariants.

---

## 0. Foundation (cross-cutting; lands before any slice)

> **Status: Complete (code + Android device sign-off — 2026-06-22).**
>
> All items in 0.1, 0.2, and 0.3 are implemented on `main` (merged from
> `phase3-foundation` + `phase3-chat-media`). **33 unit tests pass** in
> `test/features/media/` (T0.1). Manual device checks T0.2 and T0.3 were
> run on **Android** per [`assignments/CHAT_MEDIA_DEVICE_TESTS.md`](../assignments/CHAT_MEDIA_DEVICE_TESTS.md).
>
> **T0.2 — Pass.** All four `MediaPickerSheet` paths (camera photo/video,
> gallery photo/video) send successfully; media survives **hot restart** and
> **force-stop / relaunch** within the same install. Full **app uninstall
> wipes users, bases, chats, and media files** — expected for Phase 3
> local-only (SharedPreferences + app documents dir; no cloud backup).
>
> **T0.3 — Pass (Android 2026-06-22).** Denying camera or photo-library permission
> surfaces the correct snackbar; sheet auto-dismisses before snackbar (POL-1 ✅).
> "Open Settings" deep-links to the app's OS settings page (POL-2 ✅).
>
> iOS device parity for T0.2/T0.3 is **deferred** (not blocking Slice B).

### 0.1 Dependencies

- **0.1.1** Add to `pubspec.yaml`:
  - `image_picker: ^1.1.2` — camera + gallery
  - `video_player: ^2.9.2` — playback
  - `path_provider: ^2.1.4` — app documents directory
  - `mime: ^1.0.5` — content-type sniffing
  - `flutter_image_compress: ^2.3.0` *(optional; recommended for size cap)*
- **0.1.2** Run `flutter pub get`; confirm Android, iOS, Web, Windows, macOS, Linux still build (`flutter build` smoke per platform you target).
- **0.1.3** Platform permissions:
  - Android `AndroidManifest.xml`: `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`, `CAMERA`, `RECORD_AUDIO` (for video).
  - iOS `Info.plist`: `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`, `NSMicrophoneUsageDescription`.
  - macOS entitlements (if targeted): camera + microphone + user-selected files read.

### 0.2 Core abstractions

- **0.2.1** Add `lib/core/sync_status.dart`: `enum SyncStatus { localOnly, uploading, synced, failed }`. Default constant `SyncStatus.synced` for local-only writes (so future cloud swap re-interprets without migration).
- **0.2.2** Extend `lib/core/ids.dart` with `MediaId`, `StoryId`, `PostId`, `ReactionId` following the existing `BaseId`/`MessageId` pattern. Existing extensions are `.uid` / `.bid` / `.mid` / `.iid`; add `.sid` (StoryId), `.pid` (PostId), `.rid` (ReactionId). For `MediaId`, skip the extension shortcut to avoid colliding with the existing `.mid` (MessageId) and use the explicit constructor at call sites.
- **0.2.3** Add `lib/core/failure.dart` cases: `MediaTooLargeFailure`, `MediaTooLongFailure`, `MediaUnsupportedFailure`, `PermissionDeniedFailure`. Reuse `ValidationFailure` for caption/text length.

### 0.3 The `media` shared feature module

`media` is a feature without screens — pure infrastructure consumed by `chat`, `stories`, and `posts`.

- **0.3.1** Domain entities at `lib/features/media/domain/entities/`:
  - `media_ref.dart` — `MediaRef { MediaId id; MediaType type; String storageKey; String? thumbnailKey; int? width; int? height; Duration? duration; int? sizeBytes; SyncStatus syncStatus; }`
  - `media_pick_request.dart` — `source: camera|gallery`, `kind: image|video`, `maxDuration`, `maxBytes`.
  - `media_constraints.dart` — central caps: `imageMaxBytes = 10 MB`, `videoMaxBytes = 50 MB`, `videoMaxDuration = 30 s`.
- **0.3.2** Domain `MediaType` enum at `lib/features/media/domain/entities/media_type.dart` (`image`, `video`). Do not depend on legacy enum.
- **0.3.3** Domain ports at `lib/features/media/domain/repositories/`:
  - `media_storage.dart` — `Future<String> putBytes({required String key, required List<int> bytes, required String mimeType}); Future<String> resolveUri(String key); Future<void> delete(String key);`
  - `media_picker.dart` — `Future<MediaRef?> pickImage(MediaPickRequest); Future<MediaRef?> pickVideo(MediaPickRequest); Future<MediaRef?> captureFromCamera(MediaPickRequest);` (returns `null` on user cancel; throws typed failures otherwise). The dedicated `captureFromCamera` method exists today as a thin wrapper around `image_picker` with `ImageSource.camera`; the contract is shaped so a future custom in-app camera implementation is a one-file swap with no call-site changes.
- **0.3.4** Use cases at `lib/features/media/domain/usecases/`:
  - `pick_and_persist_media.dart` — orchestrates picker → validation (size/duration) → `MediaStorage.putBytes` → returns `MediaRef`.
  - `delete_media.dart` — deletes by `storageKey`.
- **0.3.5** Data implementations at `lib/features/media/data/datasources/`:
  - `local_file_media_storage.dart` — writes to `getApplicationDocumentsDirectory()/media/<baseId>/<uuid>.<ext>`. **Storage key format:** `<baseId>/<uuid>.<ext>` (relative; not absolute path). `resolveUri` joins with current docs dir → `file://...`.
  - `image_picker_media_picker.dart` — wraps `image_picker`. Implements `pickImage` (gallery), `pickVideo` (gallery), and `captureFromCamera` (uses `ImageSource.camera`, dispatches by `MediaPickRequest.kind`). Applies `MediaConstraints`. Generates a thumbnail for video via `video_player` first-frame capture (or defer thumbnail to widget if too costly).
  - `remote_media_storage.dart` — abstract; intentionally unimplemented this phase. Same signatures as `MediaStorage`.
- **0.3.6** Presentation widgets at `lib/features/media/presentation/widgets/`:
  - `media_tile.dart` — given a `MediaRef`, calls `MediaStorage.resolveUri`, then renders `Image.file` / `Image.network` for images and a tap-to-play `VideoPreview` for video. Scheme-agnostic.
  - `media_preview.dart` — full-screen viewer with pinch-zoom (image) or controls (video).
  - `media_picker_sheet.dart` — bottom sheet: "Camera (Photo)", "Camera (Video)", "Photo Library", "Video Library", "Cancel". Each option calls the corresponding `MediaPicker` method and returns `MediaRef?`. The OS camera is launched directly from the "Camera" entries — no in-app capture surface this phase.
  - `video_thumbnail.dart` — small composite for grids.
- **0.3.7** Riverpod providers at `lib/features/media/presentation/providers/media_providers.dart`:
  - `mediaStorageProvider` (override at app root with `LocalFileMediaStorage`).
  - `mediaPickerProvider` (override at app root with `ImagePickerMediaPicker`).
  - Use case providers (`pickAndPersistMediaUseCaseProvider`, `deleteMediaUseCaseProvider`).

**Testing (do now):**

- **T0.1** Unit tests under `test/features/media/`:
  - Picker (with mocked `image_picker`): `pickImage` and `pickVideo` return `null` on cancel; `captureFromCamera` dispatches by `MediaPickRequest.kind`; all three throw `MediaTooLargeFailure` over cap and `MediaTooLongFailure` over 30s.
  - `LocalFileMediaStorage`: round-trip put → resolve → file exists → delete clears it.
  - `MediaTile`: renders image for `file://` and `https://` schemes (golden or pump).
- **T0.2** Manual (Android verified 2026-06-22): from `MediaPickerSheet`, exercise (a) Camera (Photo), (b) Camera (Video), (c) Photo Library, (d) Video Library; confirm files live under `documents/media/<baseId>/<uuid>.<ext>`. Confirm media re-renders after **hot restart** or **force-stop + relaunch** (relative-key resolver). **Do not** expect chat history to survive **full app uninstall** in Phase 3 local-only — uninstall removes SharedPreferences and the app sandbox together.
- **T0.3** Manual (Android verified 2026-06-22): deny camera or photo-library permission → `PermissionDeniedFailure` snackbar with "Open Settings". POL-1 ✅ · POL-2 ✅.

---

## 1. Slice A — Chat media (images + short video)

> **Status: Complete (code + Android device sign-off — 2026-06-22).**
>
> Merged to `main`. Unit tests: **15** in `test/features/chat/` (T1.1).
> Manual device checks T1.2 and T1.3 **pass on Android**. Enhancement
> requests from device testing (gallery multi-select, video poster thumbnails)
> are **out of DoD scope** and tracked in
> [`assignments/PHASE3_MEDIA_POLISH_TICKET.md`](../assignments/PHASE3_MEDIA_POLISH_TICKET.md).

### 1.1 Domain extensions to chat

- **1.1.1** Extend `lib/features/chat/domain/entities/message.dart`: add `final List<MediaRef> media; final SyncStatus syncStatus;` with sane defaults (`const []`, `SyncStatus.synced`). Update `==` / `hashCode` / `toString`.
- **1.1.2** Add `MessageKind` enum (`text`, `media`, `system`) in chat domain — mirror legacy intent without coupling. Optional; computed from `content.isNotEmpty` + `media.isNotEmpty` is also acceptable.
- **1.1.3** Extend `ChatRepository.sendMessage(...)` signature: `required List<MediaRef> media = const []`. Existing callers compile (default).
- **1.1.4** Extend `SendMessageParams` and `SendMessage` use case: validate that **at least one of** `content` or `media` is non-empty; cap `media.length` at 4 per message (configurable in `MediaConstraints`).

### 1.2 Data updates

- **1.2.1** Update `MessageModel` (`lib/features/chat/data/models/message_model.dart`): serialize `media` as a list of `MediaRef.toMap()` and `syncStatus` as a string. Backward-compatible: missing fields → `[]` and `SyncStatus.synced`.
- **1.2.2** Update `ChatSharedPrefsDataSource.sendMessage` to accept and persist `media`.
- **1.2.3** Update `ChatRepositoryImpl.sendMessage` to forward `media`.
- **1.2.4** Mirror the same parameter on `ChatRemoteDataSource` (placeholder) for symmetry.

### 1.3 Presentation

- **1.3.1** `MessageComposer`: add a leading attach `IconButton`. On tap, opens `MediaPickerSheet`; on success, append the `MediaRef` to a local `List<MediaRef> _staged` (max 4); render a small horizontal preview strip above the input field with per-item remove (×). Disable attach when `_staged.length == max`.
- **1.3.2** `ChatScreen._sendMessage`: pass `_staged` to `chatController.send(...)`. After success, clear `_staged`. On failure, keep staged items so the user can retry.
- **1.3.3** `MessageBubble`: render `MediaTile`s above the text body (or alone, when `content.isEmpty`). Tap → `MediaPreview` route. Constrain to ~240px max width; respect mine/theirs layout.
- **1.3.4** No new providers in tile/composer (keep "dumb tiles" rule from Phase 2). Resolved URIs are computed by `MediaTile` itself via the `mediaStorageProvider`.

**Testing:**

- **T1.1** Run `flutter test test/features/chat/` and `test/features/media/`. **Pass** (106 feature tests total on `main`).
- **T1.2** Manual (Android verified 2026-06-22): send text-only (regression); send image-only; send 4 images; send a video (≤ 30s); switch base → media still loads per base. **Pass.**
- **T1.3** Manual (Android verified 2026-06-22): force-stop or hot restart app → confirm media re-renders (relative-key resolver). **Pass.**

---

## 2. Slice B — Stories (24h ephemeral + Highlights archive)

### 2.1 Base settings: enable archive + TTL override

- **2.1.1** Promote `BaseSettings` from legacy to a real domain entity at `lib/features/bases/domain/entities/base_settings.dart`. MVP fields:
  - `BaseId baseId`, `bool storiesEnabled = true`, `bool storiesArchiveEnabled = true`, `Duration storyTtl = const Duration(hours: 24)`, `int maxMediaPerStory = 1`, `DateTime updatedAt`, `UserId updatedByUserId`.
- **2.1.2** `BaseSettingsRepository` (domain) + `base_settings_shared_prefs_data_source.dart` (data). Per-base key.
- **2.1.3** Use cases: `GetBaseSettings`, `UpdateBaseSettings` (with role check: must be owner/admin to mutate; reuse `BaseRole` from `base_member`). Failure: `PermissionDeniedFailure`.
- **2.1.4** Owner-only settings screen at `lib/features/bases/presentation/screens/base_settings_screen.dart` with toggles for archive enabled and TTL (presets: 6h / 24h / 72h). Wire from sidebar/base context menu.

### 2.2 Stories feature module

`lib/features/stories/`

- **2.2.1** Domain entity `Story { StoryId id; BaseId baseId; UserId authorUserId; MediaRef media; String? caption; Duration ttl; DateTime createdAt; bool archived; SyncStatus syncStatus; }`. Computed: `bool isExpired => DateTime.now().isAfter(createdAt.add(ttl));`.
- **2.2.2** Domain repo `StoryRepository` with: `Future<Either<Failure,Story>> publishStory(...)`, `Stream<List<Story>> streamActive(BaseId)` (non-expired, non-archived), `Future<Either<Failure,List<Story>>> listArchive(BaseId)`, `Future<Either<Failure,void>> deleteStory(StoryId)`.
- **2.2.3** Use cases: `PublishStory` (validates caption ≤ 280 chars; uses `BaseSettings.storyTtl` & `maxMediaPerStory`), `ListActiveStories`, `ListArchivedStories`, `DeleteStory`, `ExpireAndArchiveStories` (sweep).
- **2.2.4** Data: `story_local_data_source.dart` (interface) + `story_shared_prefs_data_source.dart` (impl, base-keyed) + `story_remote_data_source.dart` (placeholder) + `story_repository_impl.dart` (mirrors `ChatRepositoryImpl`'s `{required local, this.remote}` constructor).
- **2.2.5** **Expiry sweep**: in `StoryRepositoryImpl`, on each `streamActive` tick (and on `publishStory`), filter out expired stories. If the parent base's `storiesArchiveEnabled` is true, mark expired stories `archived = true`; otherwise hard-delete (and call `MediaStorage.delete` for the media). Run once on app start via a small provider that reads all bases the user is a member of.
- **2.2.6** Presentation:
  - Controller `story_feed_controller.dart` (mirrors `ChatController`: `AsyncValue<List<Story>>`, `load(baseId)`, stream subscription, single source of truth).
  - Widgets: `story_bubbles_strip.dart` (horizontal list at top of base home feed), `story_bubble.dart` (avatar + colored ring; "+" bubble for the current user when none), `story_progress_bar.dart`, `story_capture_screen.dart` (pick → caption → publish), `story_viewer_screen.dart` (full-screen, swipe between authors and within an author's stories), `story_archive_screen.dart` (grid for the base's Highlights, hidden when `storiesArchiveEnabled = false`).
- **2.2.7** Wire into existing home: replace the placeholder `_FeedPage` cards in `lib/legacy/screens/home_screen.dart` with `StoryBubblesStrip` at the top. Long-press own bubble → archive shortcut. Tap "Highlights" link → `StoryArchiveScreen` (gated on `storiesArchiveEnabled`).
- **2.2.8** Routes: add `/stories/capture`, `/stories/view/:authorId`, `/stories/archive` to `lib/router.dart`.

**Testing:**

- **T2.1** Run `flutter test test/features/bases/` (settings tests) and `test/features/stories/`.
- **T2.2** Manual: publish a story; bubble appears on home; advance device clock by `ttl + 1m`, restart, confirm story is no longer in active feed and **is** in Highlights when archive is on; toggle archive off in base settings, publish a new story, expire it, confirm it's gone (and its media is deleted from disk).
- **T2.3** Base isolation: stories from base A do not appear in base B; only mutual members can view.

---

## 3. Slice C — Posts + Reactions

### 3.1 Posts feature module

`lib/features/posts/`

- **3.1.1** Domain entity `Post { PostId id; BaseId baseId; UserId authorUserId; String? text; List<MediaRef> media; DateTime createdAt; DateTime updatedAt; SyncStatus syncStatus; }`. Validation: `text` ≤ 1000 chars, `media.length` ≤ 10, at least one of text/media non-empty.
- **3.1.2** `PostRepository` (domain) + `Post*DataSource`s + `PostRepositoryImpl` (same `{required local, this.remote}` shape).
- **3.1.3** Use cases: `CreatePost`, `ListPosts(baseId, before?, limit=20)`, `DeletePost` (author or owner/admin), `StreamPosts(baseId)`.
- **3.1.4** Presentation: `post_feed_controller.dart`, `post_compose_screen.dart`, `post_card.dart` (text + `MediaTile` grid), `post_media_grid.dart` (1/2/3/4+ layouts).
- **3.1.5** Home feed integration: below `StoryBubblesStrip` in the base home feed, render an infinite list of posts via `post_feed_controller`. FAB on home → `/posts/compose`.

### 3.2 Reactions

Reactions are a separate, narrow domain so chat can opt in later without restructuring.

- **3.2.1** Domain entity `Reaction { ReactionId id; String entityId; ReactionTargetKind targetKind; UserId userId; ReactionKind kind; DateTime createdAt; }`. `ReactionTargetKind { post, story }`. `ReactionKind` enum with the locked MVP set (`like, heart, laugh, wow, sad, fire`).
- **3.2.2** `ReactionRepository`: `react(...)`, `unreact(...)`, `streamFor(entityId, targetKind)`, `listFor(entityId, targetKind)`. Uniqueness: one reaction per `(userId, entityId, targetKind)` — a second `react` with a different `kind` replaces the prior one; same `kind` is a toggle-off.
- **3.2.3** Data: `reaction_local_data_source.dart` + `reaction_shared_prefs_data_source.dart` + `reaction_repository_impl.dart`. Index by `(targetKind, entityId)` for fast lookup.
- **3.2.4** Presentation: `reaction_chip_row.dart` (counts grouped by kind, highlights the current user's selection), `reaction_picker_sheet.dart` (long-press to choose). Wire into `PostCard` and `StoryViewerScreen`.

**Testing:**

- **T3.1** Run `flutter test test/features/posts/`.
- **T3.2** Manual: create a text-only post; create a post with 4 images; delete own post; another user can't delete it; react with 👍, change to ❤️, then tap ❤️ again to remove; counts and own-reaction state survive base switch and app restart.

---

## 4. Phase 3 sign-off

- **4.1** Run full test suite: `flutter test`. Target: ≥ 80% feature-level coverage matching Phase 2 bar.
- **4.2** Manual smoke (full): chat (text + image + video), stories (publish, expire, archive, owner toggles archive off then on), posts (create, view, delete, paginate ≥ 20), reactions (post + story), base isolation (no cross-base leakage on any surface), permissions (deny camera → graceful failure UI).
- **4.3** Disk audit: after deletion of a story/post, confirm `MediaStorage.delete` was invoked and the file is gone from `documents/media/<baseId>/`.
- **4.4** No new direct dependencies in `lib/legacy/`. New code lives entirely in `lib/features/media`, `lib/features/stories`, `lib/features/posts`, and additions to existing `lib/features/chat`, `lib/features/bases`.
- **4.5** Update `README.md` Roadmap to mark Phase 3 complete; archive this DoD checklist; update `docs/MODEL_ARCHITECTURE.md` to mark Posts/Stories/Media/Reactions as ✅.

---

## Summary: testing points


| After              | Action                                                                                                                            |
| ------------------ | --------------------------------------------------------------------------------------------------------------------------------- |
| **Foundation (0)** | T0.1: `flutter test test/features/media/`. T0.2: device pick + relaunch round-trip (**Android ✅ 2026-06-22**). T0.3: permission denial UX (**Android partial ✅**). |
| **Slice A (1)**    | T1.1: `flutter test test/features/chat/ test/features/media/`. T1.2: device chat media flow (**Android ✅ 2026-06-22**). T1.3: app restart re-resolves media (**Android ✅ 2026-06-22**). |
| **Slice B (2)**    | T2.1: `flutter test test/features/bases/ test/features/stories/`. T2.2: device expiry + archive toggle. T2.3: base isolation.     |
| **Slice C (3)**    | T3.1: `flutter test test/features/posts/`. T3.2: device post + reactions flows.                                                   |
| **Sign-off (4)**   | Full `flutter test` + full device smoke + disk audit.                                                                             |
| **Polish (follow-up)** | [`PHASE3_MEDIA_POLISH_TICKET.md`](../assignments/PHASE3_MEDIA_POLISH_TICKET.md): permission snackbar layering, Open Settings, multi-pick, video thumbnails. |


---

## Recommended scaffolding (file tree)

New directories under `lib/features/`. All features follow the existing 3-layer pattern (domain / data / presentation) and the chat feature's `{required local, this.remote}` repository shape so cloud is a drop-in later.

```
lib/
├── core/
│   ├── sync_status.dart                                  # NEW
│   ├── ids.dart                                          # + MediaId, StoryId, PostId, ReactionId
│   └── failure.dart                                      # + MediaTooLarge/Long/Unsupported, PermissionDenied
│
├── features/
│   ├── media/                                            # NEW: shared module, no screens of its own
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   ├── media_ref.dart
│   │   │   │   ├── media_type.dart
│   │   │   │   ├── media_pick_request.dart
│   │   │   │   └── media_constraints.dart
│   │   │   ├── repositories/
│   │   │   │   ├── media_storage.dart                    # port
│   │   │   │   └── media_picker.dart                     # port
│   │   │   └── usecases/
│   │   │       ├── pick_and_persist_media.dart
│   │   │       └── delete_media.dart
│   │   ├── data/
│   │   │   └── datasources/
│   │   │       ├── local_file_media_storage.dart         # local impl
│   │   │       ├── image_picker_media_picker.dart        # local impl
│   │   │       └── remote_media_storage.dart             # Phase 4 stub
│   │   └── presentation/
│   │       ├── providers/media_providers.dart
│   │       └── widgets/
│   │           ├── media_tile.dart
│   │           ├── media_preview.dart
│   │           ├── media_picker_sheet.dart
│   │           └── video_thumbnail.dart
│   │
│   ├── chat/                                             # EXTEND
│   │   ├── domain/entities/message.dart                  # + media, syncStatus
│   │   ├── domain/repositories/chat_repository.dart      # sendMessage(..., media)
│   │   ├── domain/usecases/send_message.dart             # validate text-or-media, cap 4
│   │   ├── data/models/message_model.dart                # serialize media + syncStatus
│   │   ├── data/datasources/chat_shared_prefs_data_source.dart
│   │   └── presentation/widgets/
│   │       ├── message_composer.dart                     # + attach button + staged strip
│   │       └── message_bubble.dart                       # + MediaTile rendering
│   │
│   ├── bases/                                            # EXTEND
│   │   ├── domain/entities/base_settings.dart            # NEW (promoted)
│   │   ├── domain/repositories/base_settings_repository.dart
│   │   ├── domain/usecases/{get_base_settings,update_base_settings}.dart
│   │   ├── data/datasources/base_settings_shared_prefs_data_source.dart
│   │   ├── data/repositories/base_settings_repository_impl.dart
│   │   └── presentation/screens/base_settings_screen.dart
│   │
│   ├── stories/                                          # NEW
│   │   ├── domain/
│   │   │   ├── entities/story.dart
│   │   │   ├── repositories/story_repository.dart
│   │   │   └── usecases/{publish_story,list_active_stories,list_archived_stories,delete_story,expire_and_archive_stories}.dart
│   │   ├── data/
│   │   │   ├── datasources/{story_local_data_source,story_shared_prefs_data_source,story_remote_data_source}.dart
│   │   │   ├── models/story_model.dart
│   │   │   └── repositories/story_repository_impl.dart
│   │   └── presentation/
│   │       ├── controllers/story_feed_controller.dart
│   │       ├── providers/{story_providers,story_feed_vm_provider}.dart
│   │       ├── viewmodels/story_feed_vm.dart
│   │       ├── screens/{story_capture_screen,story_viewer_screen,story_archive_screen}.dart
│   │       └── widgets/{story_bubbles_strip,story_bubble,story_progress_bar}.dart
│   │
│   └── posts/                                            # NEW
│       ├── domain/
│       │   ├── entities/{post,reaction}.dart
│       │   ├── repositories/{post_repository,reaction_repository}.dart
│       │   └── usecases/{create_post,list_posts,delete_post,stream_posts,react,unreact}.dart
│       ├── data/
│       │   ├── datasources/{post_*,reaction_*}.dart
│       │   ├── models/{post_model,reaction_model}.dart
│       │   └── repositories/{post_repository_impl,reaction_repository_impl}.dart
│       └── presentation/
│           ├── controllers/{post_feed_controller,reaction_controller}.dart
│           ├── providers/{post_providers,reaction_providers}.dart
│           ├── screens/post_compose_screen.dart
│           └── widgets/{post_card,post_media_grid,reaction_chip_row,reaction_picker_sheet}.dart
│
├── router.dart                                           # + /stories/*, /posts/*, /bases/settings
└── main.dart                                             # override mediaStorageProvider, mediaPickerProvider
```

### App-root wiring (single point of override)

In `main.dart`, add overrides next to existing repository overrides:

```dart
final docsDir = await getApplicationDocumentsDirectory();
ProviderScope(
  overrides: [
    // existing chat/bases overrides...
    mediaStorageProvider.overrideWithValue(LocalFileMediaStorage(docsDir)),
    mediaPickerProvider.overrideWithValue(const ImagePickerMediaPicker()),
    storyRepositoryProvider.overrideWithValue(StoryRepositoryImpl(local: ..., remote: null)),
    postRepositoryProvider.overrideWithValue(PostRepositoryImpl(local: ..., remote: null)),
    reactionRepositoryProvider.overrideWithValue(ReactionRepositoryImpl(local: ...)),
    baseSettingsRepositoryProvider.overrideWithValue(BaseSettingsRepositoryImpl(local: ...)),
  ],
  child: const App(),
);
```

When cloud arrives in Phase 4, the only file that changes is `main.dart` (swap `LocalFileMediaStorage` for `CloudMediaStorage` and pass a non-null `remote` to each `*RepositoryImpl`).

---

## Reference: Phase 3 architectural constraints

These are the load-bearing decisions; deviation should be deliberate and documented.

1. **Local-first, cloud-ready.** Every repository accepts `{required local, this.remote}`; every entity carrying media has a `syncStatus` field; every media URI is a content-addressable key resolved at read time, never an absolute device path.
2. `**MediaStorage` is the only thing that knows about disk vs cloud.** Domain code receives `MediaRef`; widgets receive `MediaRef` and ask `MediaStorage.resolveUri`. Nothing else handles paths.
3. **Single source of truth, dumb tiles** (Phase 2 rule, preserved). Controllers (`StoryFeedController`, `PostFeedController`) own `AsyncValue<List<...>>`. `MediaTile`, `PostCard`, `StoryBubble`, etc. take props; provider reads in tiles are forbidden except for `MediaTile`'s `mediaStorageProvider` (acceptable because resolution is platform-dependent infrastructure).
4. **Base isolation by construction.** All persistence keys are scoped by `baseId` first (`mb.stories.<baseId>`, `mb.posts.<baseId>`, `media/<baseId>/...`). No cross-base list ever exists in storage.
5. **Permission-bounded mutations.** `BaseSettings` updates and post/story deletes route through use cases that check `BaseRole`. UI must not branch on role; it asks the use case and renders the resulting `Either`.
6. **Graceful permission failures.** Permission denied paths surface as `PermissionDeniedFailure` with a UI affordance to open OS settings — no silent failures.
7. **OS camera, not in-app camera, this phase.** `MediaPicker.captureFromCamera` is implemented today as an `image_picker` + `ImageSource.camera` wrapper. A custom in-app camera surface is a Phase 4 alternative implementation of the same port; design no UI or use case that depends on capabilities only a custom surface could provide (live filters, overlays, hold-to-record gestures).
8. **No streaming, no voice, no moderation tooling, no notifications this phase.** Those are Phase 4.

---

*Phase 3 DoD — drafted at Phase 2 close. Treat as living until sign-off; check items in PR descriptions referencing this file.*