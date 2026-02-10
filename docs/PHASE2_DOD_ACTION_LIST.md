# Phase 2 DoD – Action List (with Testing)

**Phase 2 DoD completed; retained for reference.** Comprehensive checklist for Phase 2 MVP and testing points.

---

## 1. Chat UI updates (Option A) — In progress

- [x] **1.1** ChatScreen: trigger `load(baseId)` when selected base **changes** (existing `ref.listen`).
- [x] **1.2** ChatScreen: trigger **initial** load when screen opens with a base already selected (read current base in same post-frame callback and call `load` if non-null).
- [x] **1.3** ChatController: single source of truth; `load()` cancels previous `_sub`, sets state on stream ticks; `send()` relies on stream to refresh (no extra providers).
- [x] **1.4** Chat list: render from controller’s `AsyncValue<List<Message>>` only (no per-message providers in list). *Verified: list uses `chatScreenVmProvider` → `chatControllerProvider`; MessageBubble/Composer are dumb.*

**Testing (do now):**
- [ ] **T1** Run chat unit tests: `flutter test test/features/chat/`
- [ ] **T2** Manual device: open app → sign in → select/create base → open Chat tab → send message → list updates. Then switch base and return to Chat → messages load for new base.

---

## 2. Presentation cleanup (“dumb” presentation)

- [ ] **2.1** Remove or stop using per-message providers in chat flow: `message_tile_vm_provider`, `message_by_id_provider`, `visible_message_ids_provider` (delete or limit to non-chat use; chat list must not depend on them).
- [ ] **2.2** Ensure no provider reads inside message tiles or composer (already the case; verify after cleanup).

**Testing:** After 2.1–2.2: run `flutter test test/features/chat/` and quick device smoke (send message, switch base).

---

## 3. Nicknames and colored names

- [ ] **3.1** Apply nickname + color at VM/controller layer (e.g. `ChatScreenVM` or a single provider) so MessageBubble receives display name and color; remove hardcoded `_getNickname` from MessageBubble and use `memberPresentationProvider` (or equivalent) once per author at list level, not per tile.

**Testing:** Run tests; device check that names and colors show correctly in chat.

---

## 4. Error handling and UI states

- [ ] **4.1** Normalize error handling: use `AsyncValue.when` (or equivalent) at screen level for loading / data / error.
- [ ] **4.2** Simple empty/loading/error states: single place in chat screen for “no messages”, “loading”, “error + retry” (already partially present; tighten and remove duplication between `_ChatMessagesList` and `_ChatMessagesFromController` if any).

**Testing:** Run full test suite; device: trigger error (e.g. invalid base) and confirm error/retry UI.

---

## 5. Quality of life (optional tighten)

- [ ] **5.1** Scroll-to-latest behavior (if not already): ensure list scrolls to bottom when new message appears (e.g. `reverse: true` and scroll controller if needed).
- [ ] **5.2** Consolidate empty/loading/error UI into one place and reuse.

**Testing:** Quick device check.

---

## 6. Phase 2 sign-off

- [ ] **6.1** Run full test suite: `flutter test`
- [ ] **6.2** Manual smoke: bases (create/join, sidebar rename/delete), invites, chat (send, receive, base change), profile, error/empty states.
- [ ] **6.3** Confirm no regressions and no use of out-of-scope extras (pagination, remote, multi-source) for MVP.

---

## Summary: testing points

| After | Action |
|-------|--------|
| **Option A (1.1–1.4)** | T1: `flutter test test/features/chat/`; T2: device chat flow + base switch. |
| **Presentation cleanup (2)** | Chat tests + device smoke. |
| **Nicknames (3)** | Tests + device names/colors. |
| **Error/UI states (4–5)** | Full `flutter test` + device error/empty/loading. |
| **Sign-off (6)** | Full `flutter test` + full device smoke. |

---

## Reference: Option A constraints (from prompt)

- Use existing `ChatRepositoryImpl` and `ChatSharedPrefsDataSource`.
- `ChatController` = single source of truth; update state with `AsyncValue.data(list)` on every stream tick (and on load).
- `load(baseId)` cancels previous subscription, starts new one, sets state on ticks.
- `send()` updates persistence; stream drives UI refresh (no extra providers).
- ChatScreen: `ref.listen` to selected base and call `load` on change; **plus** initial load when opening with base already selected.
- MessageBubble / MessageComposer: dumb (no provider reads).
- No new files; no streams at tile level; no new dependencies.
