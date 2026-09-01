# Ports, Implementations, and Mocks ΓÇö Architecture Walkthrough

**Audience:** CS undergrad heading into final year, about to build Stories.  
**Goal:** Understand *why* MoonBase splits persistence into a port, a real implementation, and a test mock ΓÇö and how those three pieces interlock ΓÇö so Stories feels like recognition, not invention.  
**Prerequisites:** Comfortable reading Dart classes and constructors. You do **not** need formal coursework on streams, state management, or ΓÇ£ports and adaptersΓÇ¥ yet.

This document teaches with **real MoonBase code** (Chat and CreateBase). `StoryRepository` / `PublishStory` are not in `lib/` yet ΓÇö you will invent them by mirroring these patterns. For mocktail drills after this, see [`MOCKS_UNIT_TESTING_CRASH_COURSE.md`](MOCKS_UNIT_TESTING_CRASH_COURSE.md). For the Stories build order, see [`STORIES_FIRST_STEPS.md`](STORIES_FIRST_STEPS.md).

---

## 0. Why youΓÇÖre reading this

When you publish a story, something has to save it. When you unit-test ΓÇ£reject a caption thatΓÇÖs too long,ΓÇ¥ you do **not** want that something to be Firestore or SharedPreferences.

MoonBase solves that with three interlocking pieces:

1. A **port** ΓÇö an abstract repository interface (method signatures only).
2. An **implementation** ΓÇö the real class that talks to storage and fulfills that interface.
3. A **mock** ΓÇö a test stand-in that also fulfills the same interface.

The thread that ties them together: **because the domain depends on the port, not on a concrete class, you can plug in the real impl in the app and a fake in tests, and the code above the port cannot tell the difference.** That swappability is the entire reason the interface exists.

---

## 1. The problem without a port

Imagine `CreateBase` imported Firestore directly:

```text
BEFORE (brittle):
  CreateBase ΓöÇΓöÇcallsΓöÇΓöÇΓû║ BaseFirestoreDataSource
                              Γöé
                              Γû╝
                         needs Firebase

  To test CreateBase, you either:
    ΓÇó spin up Firestore / SharedPreferences every time, or
    ΓÇó rewrite CreateBase for tests
```

Now the MoonBase shape:

```text
AFTER (MoonBase):
  CreateBase ΓöÇΓöÇdepends onΓöÇΓöÇΓû║ BaseRepository  (port: ΓÇ£can create a baseΓÇ¥)
                                   Γöé
                    ΓöîΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓö┤ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÉ
                    Γû╝                             Γû╝
           BaseRepositoryImpl              MockBaseRepository
                    Γöé                      (scripted in tests)
                    Γû╝
           BaseFirestoreDataSource
           (or SharedPrefs later)
```

A **port**, in this project, is a named contract ΓÇö usually an `abstract class` with method signatures and no bodies ΓÇö that says *what* persistence can do (`createBase`, `sendMessage`, ΓÇª), not *how* (Firestore document, prefs key, in-memory list).

Think of it like a USB port on a laptop: the laptop only knows ΓÇ£something that speaks USB.ΓÇ¥ You can plug in a real drive or a simulator. The laptopΓÇÖs software does not change.

---

## 2. The port ΓÇö abstract repository

### 2.1 What it looks like

Open [`lib/features/chat/domain/repositories/chat_repository.dart`](../lib/features/chat/domain/repositories/chat_repository.dart):

```dart
abstract class ChatRepository {
  Future<Either<Failure, Message>> sendMessage({
    required BaseId baseId,
    required UserId userId,
    required String content,
    List<MediaRef> media = const [],
  });

  /// Live updates for a base's messages (newest last).
  Stream<List<Message>> streamMessages(BaseId baseId);

  Future<Either<Failure, List<Message>>> listMessages({
    required BaseId baseId,
    DateTime? before,
    int limit = 50,
  });
}
```

There are **no method bodies**. That is intentional. The domain layer is declaring: ΓÇ£Whoever persists chat must be able to send, stream, and list messages.ΓÇ¥ It is deliberately silent about SharedPreferences, Firestore, JSON keys, and network retries.

Bases use the same idea ΓÇö [`base_repository.dart`](../lib/features/bases/domain/repositories/base_repository.dart) starts like this:

```dart
abstract class BaseRepository {
  Future<Either<Failure, Base>> createBase({
    required String name,
    required UserId ownerUserId,
  });
  // ... joinBase, listBases, invites, etc.
}
```

### 2.2 Either ΓÇö success or failure in the type system

YouΓÇÖll see `Either<Failure, T>` everywhere on these ports. MoonBaseΓÇÖs version lives in [`lib/core/either.dart`](../lib/core/either.dart) (homegrown ΓÇö not a third-party package):

- **`Left(Failure)`** ΓÇö something went wrong (validation, network, cache, ΓÇª).
- **`Right(T)`** ΓÇö success; `T` is the value you wanted (`Message`, `Base`, ΓÇª).

So `Future<Either<Failure, Message>>` means: ΓÇ£Eventually youΓÇÖll get either a failure or a message ΓÇö and the type system forces you to handle both.ΓÇ¥ Callers typically use `.match((failure) { ΓÇª }, (value) { ΓÇª })`.

You do not need a full functional-programming course to use this. Treat it as a typed result envelope: left bad, right good.

### 2.3 Stream ΓÇö values over time (just enough)

`streamMessages` returns a `Stream<List<Message>>`, not an `Either`. A **stream** here is simply a sequence of values over time: when a new message lands, the list updates and listeners (the chat UI) hear about it. Stories will use the same idea with something like `streamActive(BaseId)`. You do not need stream theory yet ΓÇö just know ΓÇ£one-shot call ΓåÆ `Future` / `Either`; ongoing updates ΓåÆ `Stream`.ΓÇ¥

### 2.4 Why the domain depends on the port (the key move)

Look at how `CreateBase` is typed ΓÇö [`create_base.dart`](../lib/features/bases/domain/usecases/create_base.dart):

```dart
class CreateBase implements UseCase<Base, CreateBaseParams> {
  const CreateBase(this.repo);

  final BaseRepository repo;  // ΓåÉ the port, not BaseRepositoryImpl
  // ...
}
```

And `SendMessage` ΓÇö [`send_message.dart`](../lib/features/chat/domain/usecases/send_message.dart):

```dart
class SendMessage implements UseCase<Message, SendMessageParams> {
  const SendMessage(this.repo);

  final ChatRepository repo;  // ΓåÉ the port, not ChatFirestoreDataSource
  // ...
}
```

That field type is the key architectural move. The use case **cannot** call Firestore APIs, because it never imported them. It can only call methods declared on the port. Whatever you pass into the constructor must *be* a `BaseRepository` / `ChatRepository` ΓÇö real or fake.

If the constructor took `ChatFirestoreDataSource`, every test and every future storage swap would drag that concrete class into the domain. The port stops that coupling.

---

## 3. The implementation ΓÇö fulfilling the contract

### 3.1 Same methods, real work

[`ChatRepositoryImpl`](../lib/features/chat/data/repositories/chat_repository_impl.dart) says `implements ChatRepository`, so it must provide every method the port lists:

```dart
class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl({required this.local, this.remote});

  final ChatLocalDataSource local;
  final ChatRemoteDataSource? remote;

  @override
  Future<Either<Failure, Message>> sendMessage({
    required BaseId baseId,
    required UserId userId,
    required String content,
    List<MediaRef> media = const [],
  }) =>
      guard(() async {
        final m = await local.sendMessage(
          baseId: baseId.value,
          userId: userId.value,
          content: content,
          media: media,
        );
        return m.toEntity();
      });

  // listMessages similarly; streamMessages maps models ΓåÆ entities
}
```

Read the flow carefully:

1. The impl receives domain types (`BaseId`, `UserId`).
2. It asks a **data source** to do the I/O (`local.sendMessage(...)`).
3. The data source returns a **model** (JSON/Firestore-shaped); the impl converts with `toEntity()` so the domain only ever sees `Message`.
4. `guard(...)` wraps the work so thrown exceptions become `Left(Failure)` instead of crashing the call stack.

`guard` itself is tiny ΓÇö [`error_mapper.dart`](../lib/core/error_mapper.dart):

```dart
Future<Either<Failure, T>> guard<T>(Future<T> Function() run) async {
  try {
    final v = await run();
    return Right(v);
  } catch (e) {
    return Left(mapException(e));
  }
}
```

So: **port promises Either; data source may throw; impl is the translator.**

### 3.2 Nothing above cares about Firestore vs prefs

Below the repository sits another small contract ΓÇö [`ChatLocalDataSource`](../lib/features/chat/data/datasources/chat_local_data_source.dart) ΓÇö implemented by both Firestore and SharedPreferences flavors. `ChatRepositoryImpl` only knows `local`. Swap `ChatFirestoreDataSource` for `ChatSharedPrefsDataSource` and the use case / controller code does not change.

Bases work the same way: `BaseRepository` ΓåÆ `BaseRepositoryImpl` ΓåÆ `BaseFirestoreDataSource` (or SharedPrefs). Same triangle, different feature folder.

### 3.3 Where the real one gets plugged in

Domain providers declare the **type** of the port and refuse to guess an impl ΓÇö [`chat_providers.dart`](../lib/features/chat/presentation/providers/chat_providers.dart):

```dart
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  throw UnimplementedError('Provide ChatRepository in app wiring');
});

final sendMessageUseCaseProvider =
    Provider((ref) => SendMessage(ref.read(chatRepositoryProvider)));
```

Production wiring fills that hole in [`main.dart`](../lib/main.dart):

```dart
chatRepositoryProvider.overrideWithValue(
  ChatRepositoryImpl(local: ChatFirestoreDataSource()),
),
```

That is the appΓÇÖs ΓÇ£plug the real drive into the USB portΓÇ¥ moment. Use cases read the provider, get a `ChatRepository`, and never see the class name `ChatFirestoreDataSource`.

---

## 4. The mock ΓÇö another fulfillment of the same contract

### 4.1 What a mock is here

A **mock** (in MoonBase tests) is a test stand-in that *implements the same port* so you can:

1. **Script** what methods return (`when` ΓåÆ `thenAnswer`).
2. **Check** whether the use case called the port correctly (`verify`).

No disk. No Firebase. No widgets.

The shared bases helper ΓÇö [`test/test_utils/mocks_bases.dart`](../test/test_utils/mocks_bases.dart):

```dart
class MockBaseRepository extends Mock implements BaseRepository {}

class _BaseIdFake extends Fake implements BaseId {}
class _UserIdFake extends Fake implements UserId {}

void registerBasesFallbacks() {
  registerFallbackValue(_BaseIdFake());
  registerFallbackValue(_UserIdFake());
}
```

Read the declaration out loud: **extends `Mock`** (mocktailΓÇÖs empty robot) **implements `BaseRepository`** (satisfies the portΓÇÖs type). That one line is why `CreateBase(mockRepo)` type-checks the same way as `CreateBase(realImpl)`.

(`Fake` + `registerFallbackValue` exist so mocktailΓÇÖs `any()` matcher has a dummy instance for custom types like `BaseId`. Details and pitfalls: [`MOCKS_UNIT_TESTING_CRASH_COURSE.md`](MOCKS_UNIT_TESTING_CRASH_COURSE.md).)

### 4.2 Injecting the mock where the impl would go

From [`create_base_test.dart`](../test/features/bases/domain/usecases/create_base_test.dart):

```dart
setUpAll(registerBasesFallbacks);

test('CreateBase calls repo.createBase and returns Right(Base)', () async {
  final repo = MockBaseRepository();
  final usecase = CreateBase(repo);  // same constructor the app uses

  when(() => repo.createBase(
        name: any(named: 'name'),
        ownerUserId: any(named: 'ownerUserId'),
      )).thenAnswer((_) async => Right(Base(
        id: 'b1'.bid,
        name: 'Home',
        ownerUserId: 'u1'.uid,
        createdAt: DateTime(2025, 1, 1),
      )));

  final res = await usecase(
    CreateBaseParams(name: 'Home', ownerUserId: 'u1'.uid),
  );

  expect(res, isA<Right<Failure, Base>>());
  verify(() => repo.createBase(name: 'Home', ownerUserId: 'u1'.uid)).called(1);
  verifyNoMoreInteractions(repo);
});
```

Compare to production:

| Context | What you pass to `CreateBase(...)` |
|---------|-------------------------------------|
| App | `BaseRepositoryImpl(...)` (via Riverpod override in `main.dart`) |
| Test | `MockBaseRepository()` |

`CreateBase`ΓÇÖs field is `final BaseRepository repo`. Both objects are `BaseRepository`s. **That is the swap.**

### 4.3 Proving you tested the use case, not storage

When validation fails, the repository must not be called at all. From [`join_base_test.dart`](../test/features/bases/domain/usecases/join_base_test.dart):

```dart
test('JoinBase returns ValidationFailure for bad code', () async {
  final repo = MockBaseRepository();
  final uc = JoinBase(repo);
  final res = await uc(JoinBaseParams(inviteCode: 'bad!', userId: 'u1'.uid));
  expect(res, isA<Left<Failure, Base>>());
  verifyZeroInteractions(repo); // never hits repo on invalid input
});
```

If `JoinBase` were secretly talking to Firestore, you could not assert ΓÇ£zero interactionsΓÇ¥ this cleanly. The port + mock make that proof possible.

ChatΓÇÖs `SendMessage` tests use the same idea with a file-local `_MockChatRepo extends Mock implements ChatRepository` ΓÇö identical pattern, different feature.

---

## 5. The thread ΓÇö swappability is why the interface exists

Put the three pieces on one diagram:

```text
                 UseCase
            (CreateBase / SendMessage)
                       Γöé
                       Γöé  depends only on
                       Γû╝
                ┬½port┬╗ XRepository
                 (abstract class)
                    /          \
                   /            \
                  /              \
       XRepositoryImpl      MockXRepository
              Γöé             extends Mock
              Γöé             implements XRepository
              Γû╝
         DataSource              when / verify
      (Firestore / prefs)         (no I/O)
```

- **App path:** `main.dart` overrides the provider with `XRepositoryImpl` ΓåÆ real storage.
- **Test path:** the test constructs `MockXRepository` and passes it to the use case.
- **Above the port:** validation, orchestration, controllers that call use cases ΓÇö none of them import Firestore or mocktail.

Without the port, the left and right branches cannot share a type. With the port, they are interchangeable. **The interface is not ceremony; it is the seam that makes both production wiring and unit tests possible.**

---

## 6. Where the use case sits in that picture

A **use case** is a small domain class that represents one user intention: ΓÇ£create a base,ΓÇ¥ ΓÇ£send a message,ΓÇ¥ later ΓÇ£publish a story.ΓÇ¥ MoonBaseΓÇÖs shared shape ΓÇö [`usecase.dart`](../lib/core/usecase.dart):

```dart
abstract class UseCase<Out, In> {
  Future<Either<Failure, Out>> call(In params);
}
```

`CreateBase` is the clearest worked example ΓÇö validate, then call the port:

```dart
class CreateBase implements UseCase<Base, CreateBaseParams> {
  const CreateBase(this.repo);

  final BaseRepository repo;

  @override
  Future<Either<Failure, Base>> call(CreateBaseParams p) {
    final name = p.name.trim();
    if (!isValidBaseName(name)) {
      return Future.value(
        const Left(ValidationFailure('Base name must be 1ΓÇô32 characters.')),
      );
    }
    return repo.createBase(name: name, ownerUserId: p.ownerUserId);
  }
}
```

Division of labor:

| Layer | Owns |
|-------|------|
| **Use case** | Business rules (name length, caption caps, ΓÇ£text or media requiredΓÇ¥). Can return `Left(ValidationFailure)` *without* touching the port. |
| **Port** | Capability list for persistence / I/O. |
| **Impl** | Actual storage + `guard` + modelΓåÆentity. |
| **Mock** | Scripted answers so you can test the use case in isolation. |

`SendMessage` pushes the same idea further: its file comment states that text/media validation lives in the use case **on purpose**, not in `ChatRepository`. When you write `PublishStory`, put caption / `storiesEnabled` / TTL rules in the use case the same way.

---

## 7. How youΓÇÖll apply this to Stories

You will not invent a new architecture. You will copy this triangle into `lib/features/stories/`. The feature request already sketches the port ([`STORIES_FEATURE_REQUEST.md`](STORIES_FEATURE_REQUEST.md) ┬º3.3); the living mirrors are Chat and Bases.

| Already in the repo (study this) | YouΓÇÖll build for Stories |
|----------------------------------|---------------------------|
| `ChatRepository` / `BaseRepository` | `StoryRepository` ΓÇö `publishStory`, `streamActive`, `listArchive`, `deleteStory`, ΓÇª |
| `ChatRepositoryImpl` + `ChatLocalDataSource` | `StoryRepositoryImpl` + `StorySharedPrefsDataSource` (Phase 3 local-first; same `{required local, this.remote}` shape) |
| `SendMessage` / `CreateBase` | `PublishStory` ΓÇö validate caption / settings, then `repo.publishStory(...)` |
| `MockBaseRepository` / `_MockChatRepo` | `MockStoryRepository extends Mock implements StoryRepository` (+ fallbacks for `BaseId`, `UserId`, `MediaRef`, ΓÇª) |
| `chatRepositoryProvider` + `main.dart` override | `storyRepositoryProvider` + `overrideWithValue(StoryRepositoryImpl(...))` |

### Suggested mental checklist when you start coding

1. **Entity** ΓÇö what is a `Story` in the domain? (no JSON, no prefs keys)
2. **Port** ΓÇö `abstract class StoryRepository { ΓÇª }` with Either / Stream signatures only
3. **Use case** ΓÇö `PublishStory(this.repo)` with `final StoryRepository repo`; validate first; call the port second
4. **Mock + tests** ΓÇö inject `MockStoryRepository`; assert `Left` on bad input with `verifyNever` / `verifyZeroInteractions`; assert `Right` + `verify` on the happy path
5. **Impl + data source** ΓÇö only after the port and use-case tests make sense
6. **Provider + `main.dart`** ΓÇö plug the real impl for the running app

That order matches [`STORIES_FIRST_STEPS.md`](STORIES_FIRST_STEPS.md): domain seam first, widgets and SharedPreferences later. You can unit-test `PublishStory` **before** the data source exists ΓÇö because the mock satisfies the port the same way the future impl will.

### One sentence to keep

> I depend on the port; the app injects the real implementation; my tests inject a mock; swappability is why the abstract repository exists.

When you can say that about Chat, you are ready to say it about Stories.
