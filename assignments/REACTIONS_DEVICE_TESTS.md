# Reactions (R3) device tests — session S3

> **Branch under test:** `feature/reactions-r3` → `main` after merge.
> **Plan:** calendar-home feature plan rev 2 §10 (Track C) and §10.5 (session S3).
> **Rubric:** MVP tracks acceptance, W2-A/B/C + device gates.
> **Schema / rules:** [`FIRESTORE_SCHEMA.md`](../docs/FIRESTORE_SCHEMA.md#basesbaseidreactionsreactionid--reactions-r3-flat-per-base),
> ADR [Reactions — chat un-parked, R3](../docs/FIRESTORE_SCHEMA.md#reactions--chat-untouched-un-parked-d-19-storage-r3-flat-per-base-collection-d-20),
> trigger #17 in [`FIRESTORE_UPDATE_TRIGGERS.md`](../docs/FIRESTORE_UPDATE_TRIGGERS.md).

Cloud workers can run analyzer, unit/widget tests and the Firestore emulator
only. Everything below is Philip's manual session on two physical Android
devices. **A row without an app SHA and a rules SHA is not a result.**

---

## Preconditions (all recorded before the first row)

| Item | Required state |
| ---- | -------------- |
| `main` | contains `fix/chat-send-pending` (B-c outbox) **and** `feature/reactions-r3` PR-A/B/C |
| Rules | deployed from that `main` SHA: `firebase deploy --only firestore:rules --project moonbase-aaff7` |
| Index | deployed: `firebase deploy --only firestore:indexes --project moonbase-aaff7`; Console → Firestore → Indexes shows `reactions (targetKind ASC, createdAt DESC)` **Enabled** (screenshot). Until then every live reactions query returns `failed-precondition`; the app shows chat **without chips** and logs `ReactionController: stream error` — that is the designed degraded state, **not** a pass for R1–R4. |
| App Check | unenforced (record) |
| Devices | A = Pixel 10, owner account; B = second Android, member account; same acceptance base (U-5) |
| Network | home dual-stack Wi-Fi on both; harness modes on A only, each a **full stop / re-run** install |
| Build | `fvm flutter run --release` from a clean checkout (`git status --short` empty, `git rev-parse HEAD` recorded) |

---

## Gates

| Gate | Device A (owner) | Device B (member) | Pass |
| ---- | ---------------- | ----------------- | ---- |
| **R1 react live** | Long-press B's message → picker → **heart**. | Watch the same message. | Chip `❤️ 1` appears on A **immediately** (optimistic) and on B **without refresh**; highlighted (border + bold count) on A only; B's chip un-highlighted. |
| **R2 replace** | Long-press the same message → **fire**. | Watch. | Heart chip disappears, `🔥 1` appears on both; total count unchanged (no double count at any moment on either device). |
| **R3 toggle off** | Tap the `🔥` chip (or pick fire again in the picker — sheet title reads "Tap Fire again to remove"). | Watch. | Chip row disappears on both. |
| **R4 relaunch** | — | B: force-stop, relaunch, open the chat. | Chips render from cache (cached banner may show first), then live; no `failed-precondition` text anywhere; no crash. |
| **Owner moderation** | After B reacts on A's message: rules allow A (owner) to delete B's reaction. | Long-press A's message → **like**. | **No UI affordance ships in this PR** — record "rules-only, no affordance" (rubric: not a fail). Optional proof: delete `bases/{base}/reactions/message:{msgId}:{B uid}` from the Console as the owner and watch B's chip vanish. |
| **B-c two-device (outbox)** | Full stop; run with `--dart-define=MOONBASE_BLACKHOLE=true`; send text + one image → bubble spinner → failed flag + alert (~15 s). Full stop; normal build; open chat → auto-replay **or** tap bubble → sends. | Count copies received. | **Exactly one** copy on B; ids identical on both (debug: long-press details / logcat `ChatController: Message sent successfully - <id>`). Failed bubble survived the force-stop (persisted outbox). |
| **Pending bubble has no reactions** | While a bubble is spinning/failed, long-press it. | — | Failed bubble: tap resends, long-press does nothing. Sending bubble: long-press does nothing, no chip row. (No server doc yet → rules `exists()` would deny.) |
| **Rollback** | Airplane mode on A; long-press a message → **wow**. | — | Chip appears then disappears within the write failure window; SnackBar "Couldn't update reaction: …" in plain copy (no `Exception:`); restore network, react again → sticks. Note: Firestore may queue the write offline instead of failing — if the chip simply persists and syncs on reconnect, record "queued, synced on reconnect" (also a pass). |

---

## Record

| Row | App `main` SHA | Rules SHA | Index state | App Check | Device / Android | Account | Base | Network | Build | Result | Evidence |
| --- | -------------- | --------- | ----------- | --------- | ---------------- | ------- | ---- | ------- | ----- | ------ | -------- |
| R1 | | | Enabled | unenforced | | | | dual-stack Wi-Fi | release | | |
| R2 | | | | | | | | | | | |
| R3 | | | | | | | | | | | |
| R4 | | | | | | | | | | | |
| Owner moderation | | | | | | | | | | rules-only, no affordance | |
| B-c two-device | | | | | | | | | debug + define, then release | | |
| Pending no-react | | | | | | | | | | | |
| Rollback | | | | | | | | | | | |

**Fail handling (rubric):** a rules/UI disagreement on R1–R3 is a hard fail —
fix merges and rules redeploy (new hand-off entry) before rerun. A UX-only
miss (glyph, copy, chip alignment) is recorded and may ride the #7 follow-up.
Any hang past 20 s without a surfaced state is a hard fail regardless of row.
