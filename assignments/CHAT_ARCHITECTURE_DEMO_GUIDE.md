# Chat Architecture Demo — Mentor Playbook

> **Audience:** mentor / lead engineer running a 1-on-1 session with a junior developer who is about to start the Stories ticket ([`STORIES_FEATURE_REQUEST.md`](STORIES_FEATURE_REQUEST.md)).
>
> **Purpose:** demo the existing chat feature as the architectural template for everything the junior will write next. By the end of the session, the junior should be able to point at any file in the chat slice and name the corresponding file they will create for Stories.
>
> **Time:** 90 minutes. Set a timer. Phases below are time-boxed.
>
> **Not for the junior to read.** Send them [`STORIES_FIRST_STEPS.md`](STORIES_FIRST_STEPS.md) instead.

---

## Table of Contents

1. [The punchline (state this three times during the session)](#1-the-punchline-state-this-three-times-during-the-session)
2. [Pre-demo prep](#2-pre-demo-prep)
3. [Phase 1 — Run it before you read it (10 min)](#3-phase-1--run-it-before-you-read-it-10-min)
4. [Phase 2 — Draw the architecture (5 min)](#4-phase-2--draw-the-architecture-5-min)
5. [Phase 3 — Trace one user intent through the stack (35 min)](#5-phase-3--trace-one-user-intent-through-the-stack-35-min)
6. [Phase 4 — The view-model and widget layer (15 min)](#6-phase-4--the-view-model-and-widget-layer-15-min)
7. [Phase 5 — The dependency-injection seam (10 min)](#7-phase-5--the-dependency-injection-seam-10-min)
8. [Phase 6 — The map to Stories (15 min)](#8-phase-6--the-map-to-stories-15-min)
9. [Phase 7 — Close the loop (5 min)](#9-phase-7--close-the-loop-5-min)
10. [What to watch for during the demo](#10-what-to-watch-for-during-the-demo)
11. [After the demo (follow-up exercise)](#11-after-the-demo-follow-up-exercise)
12. [Session timing summary](#12-session-timing-summary)

---

## 1. The punchline (state this three times during the session)

> "Everything you'll write for Stories has a one-to-one analog in this chat slice. By the end of today, you'll be able to point at any file in chat and name the file you'll create for Stories."

State this once at the start, once mid-way (after Phase 3), and once at the end (during Phase 6). The session is a success if the junior can do that mapping themselves by the end, and a failure if they leave understanding chat but unable to map it forward to Stories.

---

## 2. Pre-demo prep

Before the junior sits down:

1. **Run the app** and post two or three chat messages in a base. Confirm hot reload works.
2. **Open these files in tabs in this exact order** so you don't fumble during the demo:
   1. [`lib/features/chat/presentation/screens/chat_screen.dart`](../lib/features/chat/presentation/screens/chat_screen.dart)
   2. [`lib/features/chat/presentation/controllers/chat_controller.dart`](../lib/features/chat/presentation/controllers/chat_controller.dart)
   3. [`lib/features/chat/domain/usecases/send_message.dart`](../lib/features/chat/domain/usecases/send_message.dart)
   4. [`lib/features/chat/domain/repositories/chat_repository.dart`](../lib/features/chat/domain/repositories/chat_repository.dart)
   5. [`lib/features/chat/data/repositories/chat_repository_impl.dart`](../lib/features/chat/data/repositories/chat_repository_impl.dart)
   6. [`lib/features/chat/data/datasources/chat_shared_prefs_data_source.dart`](../lib/features/chat/data/datasources/chat_shared_prefs_data_source.dart)
   7. [`lib/features/chat/presentation/providers/chat_providers.dart`](../lib/features/chat/presentation/providers/chat_providers.dart)
   8. [`lib/features/chat/presentation/viewmodels/chat_screen_vm.dart`](../lib/features/chat/presentation/viewmodels/chat_screen_vm.dart)
   9. [`lib/features/chat/presentation/providers/chat_screen_vm_provider.dart`](../lib/features/chat/presentation/providers/chat_screen_vm_provider.dart)
   10. [`lib/features/chat/presentation/widgets/message_bubble.dart`](../lib/features/chat/presentation/widgets/message_bubble.dart)
   11. [`lib/main.dart`](../lib/main.dart)
3. **Have a whiteboard or large notepad ready.** You will draw the data-flow arrows three times during the session — once before the junior sees code, once during the trace, once after.
4. **Confirm the junior has read** [`STORIES_FIRST_STEPS.md`](STORIES_FIRST_STEPS.md) Section 2 (the tracer-bullet step). If they haven't, send them away to read it for 20 minutes and come back. Demoing chat to someone who hasn't done that reading is a waste of both hours.

> **Mindset for the demo.** You are not lecturing. You are running a debugger together. The IDE's "Go to Definition" (F12) is your most-used tool. Resist the urge to anticipate questions — let the code raise them.

---

## 3. Phase 1 — Run it before you read it (10 min)

Goal: prove the feature works before disassembling it. The junior will not grasp the architecture if they don't yet have a felt sense of the user-visible behavior.

**Steps:**

1. Run the app. Open the chat screen of any base. Send a message. Confirm it appears.
2. Hit `R` in the terminal (hot restart). Confirm the message is still there.
3. Switch to another base. Confirm a different (or empty) message list.
4. Switch back. Confirm the original messages return.

**Ask them out loud:**

- "Where on disk do you think this message lives right now?"
- "When I switched bases, how did the list know which messages to show?"
- "What do you think happens between hitting send and seeing the bubble appear?"

Do not correct their answers. Write them on the whiteboard verbatim. You will come back to them at the end of the session and let them update them themselves.

> **The point of this phase:** the junior should leave it with a working mental model of the *what*, even if it's wrong about the *how*. Without that, the file walk later is just abstract noise.

---

## 4. Phase 2 — Draw the architecture (5 min)

Before opening a single file, draw this on the whiteboard. Do not write any class names yet — just the boxes:

```
[ Widget ] -> [ Controller ] -> [ UseCase ] -> [ Repo (abstract) ]
                                                       |
                                                       v
                                         [ RepoImpl (data) ]
                                                       |
                                                       v
                                       [ DataSource (SharedPreferences) ]

[ Widget ] <- [ VM (Provider) ] <- [ Controller ] <- [ Stream<List<T>> ]
                                         ^
                                         |
                                  (subscribes to stream)
```

**Say:** "Events go down the left side. State flows up the right side. The whole demo is just instantiating these boxes with real Dart classes you'll see in a moment. Watch for which arrows you can't draw — those are the layer-violation traps."

Now ask: *"Which box would handle the rule that a chat message can't be empty?"* Wait for an answer. If the junior says "the widget," that's the first misconception to puncture. The correct answer is **UseCase**.

> **Why this drawing first:** the junior will see eleven files in the next 40 minutes. Without this map, each one feels novel. With it, each file is "ah, that's the UseCase box" — recognition, not learning.

---

## 5. Phase 3 — Trace one user intent through the stack (35 min)

This is the meat of the demo. You will trace exactly one user action — *typing a message and hitting send* — from the widget down to disk, and then back up to the UI. Time-box yourself: 35 minutes max. Set a timer.

### 5.1 Start at the controller, not the widget (5 min)

Counter-intuitive but important: **do not start at `chat_screen.dart`**. Widgets are leaves; if you start there the junior will spend the whole demo confused by Flutter syntax that's beside the point.

Open [`chat_controller.dart`](../lib/features/chat/presentation/controllers/chat_controller.dart). Point at three things in this order.

**(a) The state class:**

```12:19:moonbase_skeleton/lib/features/chat/presentation/controllers/chat_controller.dart
class ChatState {
  const ChatState({this.messages = const AsyncValue.data([])});

  final AsyncValue<List<Message>> messages;

  ChatState copyWith({AsyncValue<List<Message>>? messages}) =>
      ChatState(messages: messages ?? this.messages);
}
```

**Say:** "One field. One state. Three constructors (loading, data, error). This is the source of truth for the entire chat screen. Every list of messages anywhere in the app is a read of this `AsyncValue`."

**(b) The `load` method:**

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

Walk through line by line, out loud:

- "First, cancel the previous stream subscription. Forget this and you leak listeners on base switch."
- "Set state to loading. The UI immediately shows the spinner."
- "Call the list use case. Await the result. The result is an `Either<Failure, List<Message>>`."
- "Match: on the Left branch publish `AsyncValue.error`. On the Right branch publish `AsyncValue.data`. **The `Failure` never leaves this controller.**"
- "Then subscribe to the stream. Every emission replaces `messages` with fresh data."

**Ask:** "Where in this method does a `try`/`catch` block live?" *(Answer: nowhere. The junior should notice that. If they don't, point it out — it's the most important question of the demo.)*

### 5.2 Follow `send` down to the use case (5 min)

Back in the controller:

```61:74:moonbase_skeleton/lib/features/chat/presentation/controllers/chat_controller.dart
  Future<void> send(String baseId, String userId, String content) async {
    developer.log('ChatController: Sending message to base $baseId');
    final res = await _sendMessage(SendMessageParams(baseId: baseId.bid, userId: userId.uid, content: content));
    res.match(
      (failure) {
        developer.log('ChatController: Send failed - ${failure.message}');
        throw Exception(failure.message);
      },
      (message) {
        developer.log('ChatController: Message sent successfully - ${message.id.value}');
        // Stream will automatically update the UI
      },
    );
  }
```

Point at the comment *"Stream will automatically update the UI"*. **This is the single most important comment in the chat slice.** Read it aloud and pause for five seconds.

**Say:** "Notice what `send` does *not* do. It does not call `state = ...` to add the message. It does not append to a local list. It calls the use case and waits for the stream to tell us the new list."

> **The "aha" to surface:** the controller doesn't trust itself with state mutations from writes. The stream from the data source is authoritative. This is what "single source of truth" actually means in code.

F12 on `_sendMessage(...)` to jump into the use case.

### 5.3 The use case is where validation lives (5 min)

[`send_message.dart`](../lib/features/chat/domain/usecases/send_message.dart):

```17:30:moonbase_skeleton/lib/features/chat/domain/usecases/send_message.dart
class SendMessage implements UseCase<Message, SendMessageParams> {
  const SendMessage(this.repo);

  final ChatRepository repo;

@override
Future<Either<Failure, Message>> call(SendMessageParams p) {
  final content = p.content.trim();
  if (!isValidMessage(content)) {
    return Future.value(const Left(ValidationFailure('Message can't be empty and must be ≤ 1000 characters.')));
  }
  return repo.sendMessage(baseId: p.baseId, userId: p.userId, content: content);
}
}
```

**Say:** "Validation lives here. Not the widget. Not the repository. Here. If we wanted to change the max length, this is the only file that changes. If a future caller forgets to validate, the use case still rejects it."

**Ask:** "When you write `PublishStory` for Stories, what validation rules go in the equivalent place?" Make them answer from memory of the feature request. Expected answer: caption ≤ 280 chars, story-enabled check, possibly TTL clamping. If they can't recall, that's fine — make a note to revisit.

F12 on `repo.sendMessage` to jump to the abstract repository.

### 5.4 The port (3 min)

[`chat_repository.dart`](../lib/features/chat/domain/repositories/chat_repository.dart) — short file, just signatures.

**Say:** "This is an abstract class. Pure contract. No implementation. The use case talks only to this. The use case has no idea whether the messages are stored on disk, in memory, in a database, or on a server."

**Ask:** "What's the equivalent file you'll write for Stories?" *(Answer: `lib/features/stories/domain/repositories/story_repository.dart`, also abstract.)* Have them say the path out loud.

F12 on `sendMessage` to jump to the implementation.

### 5.5 The repository implementation (7 min)

[`chat_repository_impl.dart`](../lib/features/chat/data/repositories/chat_repository_impl.dart) — open the whole file.

Point at the constructor:

```10:14:moonbase_skeleton/lib/features/chat/data/repositories/chat_repository_impl.dart
class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl({required this.local, this.remote});

  final ChatLocalDataSource local;
  final ChatRemoteDataSource? remote;
```

**Say:** "Required local. Optional remote. Today, `remote` is null in `main.dart`. In Phase 4 when we have a server, `remote` becomes non-null and **nothing else changes**. This is the Phase-3-to-Phase-4 escape hatch. Memorize this constructor shape — it's the spec for every repository in the project."

Then point at `sendMessage`:

```16:22:moonbase_skeleton/lib/features/chat/data/repositories/chat_repository_impl.dart
  @override
  Future<Either<Failure, Message>> sendMessage({required BaseId baseId, required UserId userId, required String content}) =>
    guard(() async {
      final m = await local.sendMessage(baseId: baseId.value, userId: userId.value, content: content);
      return m.toEntity();
    });
```

**Walk through `guard(...)`:** F12 on it. It's in [`lib/core/error_mapper.dart`](../lib/core/error_mapper.dart). Show:

```11:18:moonbase_skeleton/lib/core/error_mapper.dart
Future<Either<Failure, T>> guard<T>(Future<T> Function() run) async {
  try {
    final v = await run();
    return Right(v);
  } catch (e) {
    return Left(mapException(e));
  }
}
```

**Say:** "This is the *only* try/catch in the entire data flow. Exceptions are converted to `Failure` values here. Above this layer — use cases, controllers, widgets — no exception handling, ever. If you write a `try` block in a use case, you've duplicated this and produced a bug."

Then point at the `.toEntity()` call. **Say:** "The data source returns `MessageModel`. The repository converts it to `Message` (the domain entity). The use case never sees the model. The widget never sees the model. Models stay in `data/`."

F12 on `local.sendMessage`.

### 5.6 The data source and the broadcast stream (10 min)

[`chat_shared_prefs_data_source.dart`](../lib/features/chat/data/datasources/chat_shared_prefs_data_source.dart) — the deepest file in the stack. Three things to show, in order:

**(a) The keys at the top:**

```13:14:moonbase_skeleton/lib/features/chat/data/datasources/chat_shared_prefs_data_source.dart
  static const _kMessages = 'mb.messages';
  static const _kMessageIds = 'mb.messageIds';
```

**Say:** "Notice the namespace prefix `mb.`. Every key in the project starts with `mb.`. Notice also that the messages map is keyed by `baseId` inside — base isolation by construction. Stories will use `mb.stories.<baseId>` keys. Reactions will use `mb.reactions.<targetKind>.<entityId>`. The prefix structure is part of the spec, not a style choice."

**(b) The `_streamControllers` map:**

```17:17:moonbase_skeleton/lib/features/chat/data/datasources/chat_shared_prefs_data_source.dart
  final Map<String, StreamController<List<MessageModel>>> _streamControllers = {};
```

**Say:** "One `StreamController.broadcast()` per base. When a message is written, we emit to that base's controller. Anyone subscribed gets the new list. This is how the controller upstream knows to update."

**(c) The `sendMessage` body:**

```65:102:moonbase_skeleton/lib/features/chat/data/datasources/chat_shared_prefs_data_source.dart
  @override
  Future<MessageModel> sendMessage({
    required String baseId,
    required String userId,
    required String content,
  }) async {
    final messageId = 'm_${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now();
    
    final message = MessageModel(
      id: messageId,
      baseId: baseId,
      userId: userId,
      content: content,
      createdAt: now,
    );

    // Save message
    final messages = _readMessages();
    final baseMessages = List<Map<String, dynamic>>.from(
      (messages[baseId] ?? <Map<String, dynamic>>[]) as Iterable<dynamic>
    );
    baseMessages.add(message.toMap());
    messages[baseId] = baseMessages;
    await _writeMessages(messages);

    // Save message ID mapping
    final messageIds = _readMessageIds();
    messageIds[messageId] = baseId;
    await _writeMessageIds(messageIds);

    // Notify stream listeners
    final allMessages = await _getMessagesForBase(baseId);
    developer.log('ChatSharedPrefsDataSource: Message saved, notifying listeners with ${allMessages.length} total messages');
    _notifyStreamListeners(baseId, allMessages);

    return message;
  }
```

Walk it slowly:

1. Generate an ID locally (the client generates IDs; Phase 4 server validates uniqueness via the `Idempotency-Key` header).
2. Build a `MessageModel`.
3. Read the existing per-base list. Append. Write back.
4. **Crucially:** emit on the broadcast stream so listeners update.
5. Return the model.

**Ask:** "What happens to `ChatController.send` if step 4 — the stream notification — were missing?" *(Answer: the message saves to disk, but the UI never updates until the next `load()`. The chat screen would feel broken even though persistence works. This is the kind of bug that's catastrophic to debug if you don't understand the architecture.)*

Now go back up the stack. Type a message in the running app while the IDE has these files open and a console showing `developer.log` output. The junior should see the logs fire in order:

```
ChatController: Sending message to base b_xxx
ChatSharedPrefsDataSource: Message saved, notifying listeners with N total messages
ChatController: Received N messages from stream
```

**Say:** "Those three log lines are the lifecycle of a send. Memorize that sequence. When you build Stories, you'll have the same three lines — `StoryController` send, `StorySharedPrefsDataSource` notify, `StoryController` stream tick."

> **The "aha" to surface in this phase:** the stream is what closes the loop. Without it, the architecture is half-broken. With it, the architecture is self-healing — `send` doesn't need to update state because the stream does.

---

## 6. Phase 4 — The view-model and widget layer (15 min)

Now and only now, go back up to the presentation.

### 6.1 The VM as a derived Provider (8 min)

[`chat_screen_vm.dart`](../lib/features/chat/presentation/viewmodels/chat_screen_vm.dart). Show it's a pure value class — no `StateNotifier`, no `ref`, just fields and a `copyWith`.

Then [`chat_screen_vm_provider.dart`](../lib/features/chat/presentation/providers/chat_screen_vm_provider.dart):

```9:51:moonbase_skeleton/lib/features/chat/presentation/providers/chat_screen_vm_provider.dart
final chatScreenVmProvider = Provider<ChatScreenVM>((ref) {
  final selectedBase = ref.watch(effectiveSelectedBaseProvider);
  final currentUser = ref.watch(currentUserProvider);
  final chatState = ref.watch(chatControllerProvider);
  
  // ... logging ...
  final baseEntity = selectedBase;

  final canSend = baseEntity != null && currentUser != null;

  return chatState.messages.when(
    data: (messages) => ChatScreenVM(
      selectedBase: baseEntity,
      currentUser: currentUser,
      messages: messages,
      isLoading: false,
      error: null,
      canSendMessage: canSend,
    ),
    loading: () => ChatScreenVM(/* ... */),
    error: (error, _) => ChatScreenVM(/* ... */),
  );
});
```

**Say three things:**

1. **It's a `Provider`, not a `StateNotifierProvider`.** A VM is a derived value; it has no mutations of its own.
2. **It watches three upstream providers and flattens the result.** The VM is the join point where chat state, base selection, and current user come together.
3. **The `.when(...)` block** turns the `AsyncValue` into concrete props the widget can read directly. The widget never sees an `AsyncValue` — it sees `isLoading: bool` and `error: String?`. That's the projection job.

**Ask:** "If we wanted to disable the send button when the user has been muted, where would that check live?" *(Answer: in the VM. `canSendMessage` is a VM-level boolean computed from upstream state. The widget never decides; it asks.)*

### 6.2 Dumb tiles (5 min)

[`message_bubble.dart`](../lib/features/chat/presentation/widgets/message_bubble.dart). Point at the imports and the constructor.

**Say:** "No `ref.watch`. No `ref.read`. No `Provider` mentions anywhere. This widget receives a `Message` and a `currentUserId` as props. It renders. That's it."

**Ask:** "Why? What does this rule buy us?" Multiple right answers:

- Trivial widget tests (no `ProviderScope` needed).
- The widget is portable across screens.
- No N+1 provider reads when rendering a list of 100 bubbles.
- The single-source-of-truth invariant holds — only the controller publishes state.

> **The "aha" to surface:** widgets that read providers create an N+1 problem for free. Disciplined VM hoisting eliminates the whole class of bugs.

### 6.3 The screen itself (2 min)

[`chat_screen.dart`](../lib/features/chat/presentation/screens/chat_screen.dart). Don't dwell. Just point at:

- It's a `ConsumerStatefulWidget`.
- It calls `ref.read(chatControllerProvider.notifier).load(baseId)` in `initState`.
- It reads `chatScreenVmProvider` to get its props.
- The build method is mostly an `AsyncValue.when(...)` (or its VM-flattened equivalent).

**Say:** "Screens orchestrate. They wire VMs to widgets. They don't compute. If you find logic in a screen's build method, it belongs in the VM."

---

## 7. Phase 5 — The dependency-injection seam (10 min)

This is the unsexy phase that ties everything together. Skip it and the junior won't understand how anything actually runs.

### 7.1 The throwing provider (3 min)

[`chat_providers.dart`](../lib/features/chat/presentation/providers/chat_providers.dart):

```7:14:moonbase_skeleton/lib/features/chat/presentation/providers/chat_providers.dart
/// Override at app root with a concrete repo.
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  throw UnimplementedError('Provide ChatRepository in app wiring');
});

final sendMessageUseCaseProvider   = Provider((ref) => SendMessage(ref.read(chatRepositoryProvider)));
final streamMessagesUseCaseProvider = Provider((ref) => StreamMessages(ref.read(chatRepositoryProvider)));
final listMessagesUseCaseProvider   = Provider((ref) => ListMessages(ref.read(chatRepositoryProvider)));
```

**Say:** "Read line 8 carefully. The provider throws. On purpose. This file is the seam — domain and presentation depend on this token; nothing imports the concrete implementation. The throw guarantees that production code can't run unless `main.dart` provides an override."

**Ask:** "Why a throw instead of returning a fake or null?" *(Answer: silent fallbacks hide wiring bugs until users notice them. A throw on app start is loud and immediate.)*

### 7.2 The override in main (5 min)

[`lib/main.dart`](../lib/main.dart). Point at the overrides list:

```41:65:moonbase_skeleton/lib/main.dart
  final overrides = <Override>[
    sharedPrefsProvider.overrideWithValue(prefs),

    profile_providers.profileRepositoryProvider.overrideWithValue(ProfileRepositoryImpl(prefs)),

    authRepositoryProvider.overrideWithValue(
      AuthRepositoryImpl(local: AuthLocalDataSourceImpl(prefs)),
    ),

    chatRepositoryProvider.overrideWithValue(
      ChatRepositoryImpl(local: ChatSharedPrefsDataSource(prefs)),
    ),
    // ...
  ];
```

**Say:** "This is the only file in the entire app that imports both `data/` and `presentation/`. This is on purpose. When Phase 4 cloud sync lands, **this is the only file that changes** — we pass a non-null `remote` to each repo. Every other file in the project is already cloud-ready."

**Ask:** "When you build Stories, what new lines appear in this overrides list?" *(Answer the junior should produce: `storyRepositoryProvider.overrideWithValue(StoryRepositoryImpl(local: StorySharedPrefsDataSource(prefs), media: mediaStorage, settings: baseSettingsRepository))`. If they can produce the constructor shape from memory, you've succeeded.)*

### 7.3 Break it on purpose (2 min)

Comment out the `chatRepositoryProvider.overrideWithValue(...)` line. Hot restart. The app crashes with `UnimplementedError: Provide ChatRepository in app wiring`.

**Say:** "This is by design. The provider throws until wired. There's no silent default. When you forget to wire `storyRepositoryProvider` in `main.dart`, you'll see the same crash. That's how you'll diagnose it."

Uncomment, restart, confirm chat works again.

---

## 8. Phase 6 — The map to Stories (15 min)

The final phase. This is where you cash in everything you just demonstrated.

On the whiteboard, draw a two-column table:

| Chat file (read-only reference) | Stories file (the junior will create) |
| --- | --- |
| `lib/features/chat/domain/entities/message.dart` | `lib/features/stories/domain/entities/story.dart` |
| `lib/features/chat/domain/repositories/chat_repository.dart` | `lib/features/stories/domain/repositories/story_repository.dart` |
| `lib/features/chat/domain/usecases/send_message.dart` | `lib/features/stories/domain/usecases/publish_story.dart` |
| `lib/features/chat/data/models/message_model.dart` | `lib/features/stories/data/models/story_model.dart` |
| `lib/features/chat/data/datasources/chat_shared_prefs_data_source.dart` | `lib/features/stories/data/datasources/story_shared_prefs_data_source.dart` |
| `lib/features/chat/data/repositories/chat_repository_impl.dart` | `lib/features/stories/data/repositories/story_repository_impl.dart` |
| `lib/features/chat/presentation/providers/chat_providers.dart` | `lib/features/stories/presentation/providers/story_providers.dart` |
| `lib/features/chat/presentation/controllers/chat_controller.dart` | `lib/features/stories/presentation/controllers/story_feed_controller.dart` |
| `lib/features/chat/presentation/viewmodels/chat_screen_vm.dart` | `lib/features/stories/presentation/viewmodels/story_bubbles_strip_vm.dart` (and others) |
| `lib/features/chat/presentation/widgets/message_bubble.dart` | `lib/features/stories/presentation/widgets/story_bubble.dart` |

**Say:** "Eleven chat files. Eleven Stories files. One-to-one. This is what 'mirror the chat slice' means."

Then walk through the **differences** — the things the junior can't just copy. There are only four, and they're all small:

1. **Story has a singular `MediaRef`** where Message has a `String content`. Posts will have a list.
2. **Story has a TTL and expiry sweep.** The repository filters expired rows on every read and every stream tick. Chat has no equivalent.
3. **Story respects `BaseSettings`.** `PublishStory` reads `storiesEnabled`, `storyTtl`, `maxMediaPerStory` from settings injected via params. Chat has no equivalent.
4. **Reactions on Stories** are an additive slice that mirrors chat-controller patterns but with optimistic updates and rollback (covered in the feature request, but not the first six steps).

Everything else is mechanical translation.

**Final question to ask before ending the session:** "Pick any file in the chat slice. Tell me what the corresponding Story file is called and what it does." Make the junior do this three times with three different files. If they can do it without looking, you're done.

---

## 9. Phase 7 — Close the loop (5 min)

Go back to the whiteboard from Phase 1, where you wrote down the junior's original guesses about how the architecture worked. Read each one aloud. Ask them to update it.

Then re-state the punchline: *"Everything you'll write for Stories has a one-to-one analog in this chat slice. Now you have the map."*

**Concrete next steps to send the junior off with:**

1. Re-read [`STORIES_FIRST_STEPS.md`](STORIES_FIRST_STEPS.md) end to end. With the chat slice now in their head, that doc will read very differently.
2. Start on Step 1 (`BaseRole` + `BaseSettings`). The first concrete file they write should be `base_role.dart` — a four-line enum. It will feel anticlimactic. That's correct.
3. They should **not** write any presentation code, any widget code, or any `SharedPreferences` code before getting Steps 1–5 reviewed in a draft PR. Re-emphasize this; it's the single piece of advice juniors most often ignore.

---

## 10. What to watch for during the demo

A few signals that should make you pause:

- **They're quiet.** Juniors often don't ask questions because they don't yet know what they don't know. Stop every 10 minutes and force a recap question.
- **They focus on syntax.** "What does `Either` do?" "Why is there a `?` after `remote`?" — these are valid but a trap. Defer them to a 1:1 follow-up. The demo is about the architecture, not the language.
- **They ask "can I just do X simpler?"** Usually the answer is no, and the reason is preserved invariants (single source of truth, base isolation, cloud-ready ports). Have an answer ready for the three most likely "simpler" suggestions:
  - "Can the widget just call the data source directly?" — No: layer violation, untestable, blocks Phase 4 cloud swap.
  - "Can the controller hold the list in a `List<Message>` instead of an `AsyncValue`?" — No: you lose loading/error states; every screen reinvents them.
  - "Can I skip the use case and call the repo from the controller?" — Technically yes, structurally no: validation and cross-feature joins live in the use case; skipping it pushes them into the controller or the widget where they bit-rot.
- **They're nodding too much.** Suspicious. Make them drive the keyboard for the last 10 minutes — have them use F12 to navigate, have them predict what's in a file before opening it.

---

## 11. After the demo (follow-up exercise)

Send a short follow-up message (a chat message is fine, no doc needed):

> Three questions to answer in writing before our next sync:
>
> 1. In the chat slice, where does the rule "messages can't be empty" live? Cite the file path and the lines.
> 2. If we wanted to add a server backend tomorrow, which files would change? Be exhaustive.
> 3. Why does `ChatController.send` not call `state = state.copyWith(...)` after a successful send?

If they can answer all three correctly, they're ready to write code. If they can't, do a 30-minute follow-up on the specific question they missed before letting them commit anything.

---

## 12. Session timing summary

Glance at this during the session to stay on track. If you're 10 minutes behind by the end of Phase 3, **cut Phase 4.3 and Phase 7** to recover — never cut Phase 6 (the map to Stories).

| Phase | What | Time | Cumulative |
| --- | --- | --- | --- |
| 1 | Run it before you read it | 10 min | 10 |
| 2 | Draw the architecture | 5 min | 15 |
| 3 | Trace one user intent (six sub-phases) | 35 min | 50 |
| 4 | View-model and widget layer | 15 min | 65 |
| 5 | Dependency-injection seam | 10 min | 75 |
| 6 | Map to Stories | 15 min | 90 |
| 7 | Close the loop | 5 min | 95 |

The session is designed for 90 minutes of code time plus 5 minutes of closing reflection. If the junior is engaged and asking good questions, let it run to 100 minutes. If they're disengaging by minute 60, stop, take a break, and resume the next day — pushing through a tired junior produces zero retention.

---

## Related documents

- [`STORIES_FEATURE_REQUEST.md`](STORIES_FEATURE_REQUEST.md) — the ticket the junior is preparing to start.
- [`STORIES_FIRST_STEPS.md`](STORIES_FIRST_STEPS.md) — the junior's solo guide for the first six steps. Send to them before this demo, not after.
- [`STORIES_FIRST_STEPS_REFERENCE.md`](STORIES_FIRST_STEPS_REFERENCE.md) — worked code for the first six steps. Junior should use sparingly.
- [`../docs/PHASE3_POSTS_STORIES_REACTIONS_BLUEPRINT.md`](../docs/PHASE3_POSTS_STORIES_REACTIONS_BLUEPRINT.md) — architectural blueprint behind the demo.
- [`../docs/PHASE3_DOD_ACTION_LIST.md`](../docs/PHASE3_DOD_ACTION_LIST.md) — slice-level DoD.
- [`../docs/DEV_GUIDE.md`](../docs/DEV_GUIDE.md) — existing Flutter / Git workflow notes the junior will follow.

---

*Mentor playbook. Reusable across juniors — the chat slice changes infrequently, so this script should stay accurate. If the chat slice is meaningfully refactored, update the line-numbered citations in Phases 3 and 5.*
