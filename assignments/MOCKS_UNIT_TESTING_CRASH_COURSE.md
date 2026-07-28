# Unit Testing Crash Course: Mocks in MoonBase

**Audience:** CS undergrad (final year), new to mocking.  
**Goal:** In ~30 minutes, understand *why* we mock, *what* we mock in our 3-layer architecture, and *how* to write the first Stories use-case tests with **mocktail**.  
**Prerequisites:** You have (or are about to have) a domain use case like `PublishStory` that takes a `StoryRepository` interface. You do **not** need widgets or SharedPreferences working yet.

---

## 0. Demo agenda (for the mentor — ~30 min)

| Time | Segment | Live artifact |
|------|---------|----------------|
| 0–5 | Why not hit SharedPreferences / Firebase in every test? | Whiteboard: layers |
| 5–12 | What is a mock? Fake vs real collaborator | Open `mocks_auth.dart` |
| 12–22 | Anatomy of one MoonBase test | Live-read `create_base_test.dart` or `sign_in_test.dart` |
| 22–28 | Write / walk `PublishStory` three tests | `STORIES_FIRST_STEPS.md` §7.1 |
| 28–30 | Pitfalls + homework | Fallbacks, `verifyNever`, what *not* to mock |

Junior takeaway sentence: **“I test *my* class; I fake the classes it talks to at the repository boundary.”**

---

## 1. The mental model (5 minutes)

### 1.1 Unit test = one unit under test

In MoonBase, a **unit** for early Stories work is usually a **use case** (e.g. `PublishStory`).

```text
  PublishStory  ←── you are testing THIS
       │
       ▼
  StoryRepository  ←── you FAKE this (mock)
       │
       ▼  (not in this test)
  SharedPreferences / Firestore / files
```

You are **not** testing the whole app. You are answering:

> Given these inputs, does `PublishStory` validate correctly and call the repository the right way?

### 1.2 Why the repository interface exists (same story as Auth/Firebase)

```text
Presentation  →  Controller / Widget
Domain        →  Use case  →  StoryRepository  (interface)
Data          →  StoryRepositoryImpl → data sources
```

- Use cases depend on **`StoryRepository`**, not on prefs or Firebase.
- In **production**, `main.dart` plugs in the real impl.
- In **tests**, you plug in a **mock** that implements the same interface.

That is why you can unit-test Stories **before** the data source or widgets exist.

### 1.3 Analogy (CS undergrad-friendly)

Think of `StoryRepository` as a **USB port**.

- The use case only knows “something that can `publishStory`.”
- Production plugs in a real drive (SharedPreferences / later Firestore).
- Tests plug in a **simulator** that returns whatever you script (`Right(story)` or `Left(failure)`).

If you wired the use case directly to SharedPreferences, every test would need disk setup, and cloud migration would break all those tests.

---

## 2. What is a mock? (concept)

| Term | Meaning in this project |
|------|-------------------------|
| **Mock** | A generated stand-in for an interface (`Mock implements StoryRepository`). You **script** return values and later **verify** calls. |
| **Stub** | The scripted return: `when(...).thenAnswer(...)`. People say “stub the repo to return Right.” |
| **Fake** | A tiny hand-written stand-in (we use `Fake` for `BaseId`/`UserId` fallbacks). |
| **Spy** | Not a separate type here — `verify` on a mock acts like a spy (“was this called?”). |

**We use [`mocktail`](https://pub.dev/packages/mocktail)** (already in `pubspec.yaml` `dev_dependencies`). Prefer it over writing manual fake classes unless the fake needs real behavior.

### What we mock vs what we don’t

| Mock this | Don’t mock this |
|-----------|-----------------|
| Repository **interfaces** (`StoryRepository`, `AuthRepository`, `BaseRepository`) | Entities (`Story`, `User`, `Base`) — construct real ones |
| Sometimes data sources when testing a **repository impl** | `Either` / `Failure` — use real `Right` / `Left` / `ValidationFailure` |
| | Validators / pure functions — call them for real |

**Rule:** Mock **across the architecture boundary** (domain ↔ data). Do not mock the thing you’re testing.

---

## 3. How MoonBase does it (implementation)

### 3.1 One-liner mock class

Shared helpers live under `test/test_utils/`:

```dart
// test/test_utils/mocks_auth.dart
import 'package:mocktail/mocktail.dart';
import 'package:moonbase_skeleton/features/auth/domain/repositories/auth_repository.dart';

class MockAuthRepository extends Mock implements AuthRepository {}
```

For Stories, same pattern (file-local is fine for your first PR):

```dart
class MockStoryRepository extends Mock implements StoryRepository {}
```

`extends Mock implements StoryRepository` means: “pretend to be a `StoryRepository`; every method is empty until I stub it.”

### 3.2 The four beats of every use-case test

Memorize this loop:

1. **Arrange** — create mock + use case; `when(...).thenAnswer(...)`  
2. **Act** — `await useCase(params)`  
3. **Assert result** — `expect` on `Right` / `Left`  
4. **Assert interaction** — `verify` / `verifyNever` / `verifyNoMoreInteractions`

### 3.3 Live example: `CreateBase` (shortest happy path)

File: `test/features/bases/domain/usecases/create_base_test.dart`

```dart
final repo = MockBaseRepository();
final usecase = CreateBase(repo);

// 1. Stub: when createBase is called with ANY name/owner, return this Base
when(() => repo.createBase(
      name: any(named: 'name'),
      ownerUserId: any(named: 'ownerUserId'),
    )).thenAnswer((_) async => Right(Base(
      id: 'b1'.bid,
      name: 'Home',
      ownerUserId: 'u1'.uid,
      createdAt: DateTime(2025, 1, 1),
    )));

// 2. Act
final res = await usecase(
  CreateBaseParams(name: 'Home', ownerUserId: 'u1'.uid),
);

// 3. Assert outcome
expect(res, isA<Right<Failure, Base>>());

// 4. Assert the use case talked to the repo correctly
verify(() => repo.createBase(name: 'Home', ownerUserId: 'u1'.uid)).called(1);
verifyNoMoreInteractions(repo);
```

**Read it out loud:**  
“I don’t care how the repo stores a base. I only care that `CreateBase` calls `createBase` once with the right args and returns the `Right` the repo gave it.”

### 3.4 Live example: validation that must **not** call the repo

From Sign-in / the Stories plan — the most important pattern for `PublishStory`:

```dart
// Arrange: invalid input — do NOT stub the repo (or stub and prove it wasn't used)
final result = await useCase(SignInParams(email: '', password: 'secret1'));

expect(result, isA<Left<Failure, User>>());
verifyNever(() => mockRepository.signIn(
      email: any(named: 'email'),
      password: any(named: 'password'),
    ));
```

**Why `verifyNever` matters:** It proves validation lives in the use case. If someone later “helps” by moving validation into the repository, this test fails — good.

### 3.5 API cheatsheet (mocktail)

| API | Purpose |
|-----|---------|
| `when(() => repo.foo(...)).thenAnswer((_) async => Right(...))` | Stub async success |
| `when(...).thenAnswer((_) async => const Left(ValidationFailure('…')))` | Stub failure |
| `when(...).thenReturn(...)` | Sync returns only (rare for our repos) |
| `any(named: 'caption')` | Matcher: “any value for this named arg” in `when` |
| `verify(() => repo.foo(...)).called(1)` | Must have been called once with these args |
| `verifyNever(() => repo.foo(...))` | Must not have been called |
| `verifyNoMoreInteractions(repo)` | No surprise extra calls |
| `registerFallbackValue(...)` | Needed before `any()` on custom types (see below) |

### 3.6 `any()` and fallback values (the #1 junior footgun)

Mocktail needs a **dummy instance** for non-nullable custom types when you use `any()`:

```dart
// test/test_utils/mocks_bases.dart
void registerBasesFallbacks() {
  registerFallbackValue(_BaseIdFake());
  registerFallbackValue(_UserIdFake());
}

// in the test file:
void main() {
  setUpAll(registerBasesFallbacks);
  // ...
}
```

If you see:

> `Bad state: A test tried to use \`any\` … but there was no registered fallback value`

→ add a `Fake` for that type and `registerFallbackValue` in `setUpAll`.

For Stories, if `publishStory` takes `BaseId`, `UserId`, `MediaRef`, etc., register fallbacks for those types once per test file (or add `mocks_stories.dart` next to the other test utils).

### 3.7 `setUp` vs `setUpAll`

| Hook | Use for |
|------|---------|
| `setUpAll` | Register fallbacks once per file |
| `setUp` | Fresh `MockStoryRepository()` + `PublishStory(repo)` **before each test** so stubs don’t leak between tests |

Pattern from `sign_in_test.dart`:

```dart
late PublishStory useCase;
late MockStoryRepository mockRepository;

setUp(() {
  mockRepository = MockStoryRepository();
  useCase = PublishStory(mockRepository);
});
```

---

## 4. Your first Stories tests (the demo payoff)

Target file (from `assignments/STORIES_FIRST_STEPS.md` §7.1):

`test/features/stories/domain/usecases/publish_story_test.dart`

| # | Test | Stub? | Assert |
|---|------|-------|--------|
| 1 | `rejects when storiesEnabled is false` | No need (or unused) | `Left`; **`verifyNever`** on `publishStory` |
| 2 | `rejects captions over 280 chars` | No | `Left(ValidationFailure)`; **`verifyNever`** |
| 3 | `trims caption and forwards to repo on success` | `when(...).thenAnswer((_) async => Right(fakeStory))` | `Right`; **`verify`** called with `caption: 'hello'` once |

Skeleton:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
// import your Story, StoryRepository, PublishStory, Either, Failure, ids, settings...

class MockStoryRepository extends Mock implements StoryRepository {}

void main() {
  late PublishStory useCase;
  late MockStoryRepository repo;

  setUp(() {
    repo = MockStoryRepository();
    useCase = PublishStory(repo);
  });

  test('rejects when storiesEnabled is false', () async {
    final settings = /* BaseSettings with storiesEnabled: false */;
    final result = await useCase(PublishStoryParams(
      // ... valid media, etc.
      settings: settings,
    ));

    expect(result.isLeft, isTrue); // or isA<Left<...>>()
    verifyNever(() => repo.publishStory(
          baseId: any(named: 'baseId'),
          authorUserId: any(named: 'authorUserId'),
          media: any(named: 'media'),
          caption: any(named: 'caption'),
          ttl: any(named: 'ttl'),
        ));
  });

  // tests 2 and 3 follow the same shape as CreateBase / SignIn
}
```

**Run:**

```bash
fvm flutter test test/features/stories/domain/usecases/publish_story_test.dart
```

---

## 5. How this scales as you add layers

| When you build… | Unit-test by mocking… |
|-----------------|------------------------|
| Use case (`PublishStory`) | `StoryRepository` |
| Repository impl (`StoryRepositoryImpl`) | `StoryLocalDataSource` / remote (mock the **data sources**) |
| Controller | Use cases **or** repository — prefer mocking use cases if the controller only orchestrates |
| Widget | Usually **not** mocktail-first; use `ProviderScope` overrides with fakes, or pump with a test controller |

**Do not** jump to widget tests until domain + data contracts are green. Mocks shine earliest at the **use case** layer.

---

## 6. Common mistakes (call these out in the demo)

1. **Mocking the use case while testing the use case** — you’re testing nothing.  
2. **Forgetting `async` / `thenAnswer`** — repo methods return `Future`; use `thenAnswer((_) async => ...)`.  
3. **Stubbing with `any()` but verifying with wrong args** — stub can be loose; verify should be **exact** on the values you care about (e.g. trimmed caption).  
4. **Not using `verifyNever` on validation tests** — weak tests that still pass if the repo is called incorrectly.  
5. **Reaching into SharedPreferences in a use-case test** — architecture smell; fix the dependency direction.  
6. **Shared mock instance without `setUp`** — test B inherits stubs from test A → flaky suite.  
7. **Missing `registerFallbackValue`** — cryptic mocktail error; fix once in `setUpAll`.

---

## 7. Mini glossary for the PR description

> Unit-tested `PublishStory` with mocktail: repository is mocked so validation and caption-trim behavior are proven without a data source. Happy path verifies a single `publishStory` call with trimmed caption; disabled stories / long caption paths use `verifyNever`.

---

## 8. Homework after the 30 minutes

1. Open and read end-to-end:  
   - `test/test_utils/mocks_bases.dart`  
   - `test/features/bases/domain/usecases/create_base_test.dart`  
   - `test/features/auth/domain/usecases/sign_in_test.dart` (validation + `verifyNever`)  
2. Write the three `PublishStory` tests; push on your Stories branch.  
3. Optional stretch: add a fourth test — repo returns `Left(UnknownFailure(...))` and the use case forwards that `Left` unchanged (proves you don’t swallow failures).

---

## 9. Mentor tip — what “success” looks like

The junior can explain, without notes:

1. Why the use case doesn’t import SharedPreferences.  
2. What `when` / `verify` / `verifyNever` each prove.  
3. Why `CreateBase` / `PublishStory` tests can pass before any widget exists.

When they can say that, they’re ready to unit-test the rest of the Stories domain the same way.

---

*Companion docs: [`STORIES_FIRST_STEPS.md`](STORIES_FIRST_STEPS.md) §7–7.1, [`CHAT_ARCHITECTURE_DEMO_GUIDE.md`](CHAT_ARCHITECTURE_DEMO_GUIDE.md), [`docs/CLOUD_FIRESTORE_TEST_EXPANSION.md`](../docs/CLOUD_FIRESTORE_TEST_EXPANSION.md) (later: what changes when the repo’s remote is Firestore).*
