# Calendar Home — device tests (session S2)

> **Branch under test:** `main` after `feature/calendar-home` merges.
> **Rules:** deployed by Philip from the `main` SHA that contains the calendar rules (see `docs/FIRESTORE_SCHEMA.md` §Calendar; hand-off block at the end of the PR). **Do not start S2 before that hand-off is recorded.**
> **Index:** none required (single-field range + orderBy on `startAt`). App Check: unenforced.
> **Devices:** A = Pixel 10, **owner** account of the acceptance base · B = second Android, **member** account. Same base, both on the home dual-stack Wi-Fi. Release builds (`fvm flutter run --release`) unless a row says otherwise.
> **Plan:** `docs/calendar-home-feature-plan.md` §7 (Project store) · rubric W1 device gates.

Cloud workers cannot run these. Everything below is Philip's, on two physical devices.

---

## Pre-flight (5 min)

1. Both devices: clean checkout of the recorded `main` SHA (`git status --short` empty), `fvm flutter pub get`, `fvm flutter run --release -d <device>`.
2. Confirm the rules hand-off entry for this SHA exists and matches `firestore.rules` on that commit.
3. A signed in as the base owner, B as a member of the same base; both on the Home tab (agenda visible, "Showing 7 days back · 30 days ahead").
4. Sanity: B has **no** gear icon next to the window label; A has one.

---

## Gates

| Gate | Device A (owner) | Device B (member) | Pass |
|---|---|---|---|
| **C1 live sync** | FAB "Add event" → title "C1 dinner", today, 19:00–20:00, notes "bring dessert" → Add. | Stay on Home; do not pull/refresh. | Card appears on B without any interaction; time shows `7:00 PM – 8:00 PM` (device locale); author chip shows A's nickname/colour (same as chat); today section is highlighted and the list opened scrolled to today; no cached banner after the first live emission. |
| **C2 window + policy** | Gear → **Month** → **Save** (no change) → gear → **Week** (0/7) → Save. Then FAB → event **20 days ahead** — the date picker must refuse it (only 0–7 days selectable). Set date +5 days → Add. Then gear → **Owner only** → Save. | Observe. After A switches to Owner only, try to add (FAB should be gone). If B still has an editor sheet open from before the switch, submit it. | B's label changes to "Showing 0 days back · 7 days ahead" live and the list shrinks; the +5-day event appears on both; B never had a gear; B's FAB disappears when the policy flips; a stale create from B is rule-denied and surfaces a plain snackbar message (no `Exception:` prefix, no raw code); A can still add under Owner only. |
| **C3 permissions + relaunch** | Watch B's edit arrive. Then tap B's event → **Delete** (owner may) → confirm. | Tap own event → Edit → rename to "C3 mine (edited)" → Save. Tap A's "C1 dinner" → confirm **no Edit/Delete buttons**. Then force-stop the app, turn Wi-Fi off, relaunch, open Home. Turn Wi-Fi back on. | B's rename appears on A; A's event is read-only on B; on relaunch offline B shows the cached agenda **with** the "Showing events saved on this device." banner (after ~0.4 s), no crash, no spinner past 20 s; once Wi-Fi returns the banner clears and A's delete is reflected. |
| **B-e home states** (fresh install on B) | — | Uninstall, reinstall, Wi-Fi **off**, sign in with an account whose bases are not cached → Home. Then sign in on Wi-Fi, open Home once (cache warm), drop Wi-Fi, force-stop, relaunch → Home. | Never shows "Create your first base" while loading or errored: a neutral skeleton while loading; "Can't reach MoonBase right now." + Retry once the 20 s guard fires on the failed bases read; Retry succeeds when Wi-Fi is restored. With a warm cache, the agenda renders from cache with the cached banner. |

**U-1 / U-2 check (record, don't fix):** C3 assumes a member may edit/delete **their own** events under Owner only (rules + use cases + tests all encode this). C1 assumes UTC storage / device-local display. If Philip decides otherwise, record it here and re-judge.

---

## Record

| Row | Result | App `main` SHA | Rules SHA | Index | App Check | Device / Android | Account | Base | Network | Build | Evidence |
|---|---|---|---|---|---|---|---|---|---|---|---|
| C1 | | | | none | unenforced | A: Pixel 10 / · B: / | | | home dual-stack | release | |
| C2 | | | | none | unenforced | | | | | release | |
| C3 | | | | none | unenforced | | | | | release | |
| B-e | | | | none | unenforced | B fresh install | | | Wi-Fi off → on | release | |

A row without an app SHA **and** a rules SHA is not a result. A rules/UI disagreement in C2 is a hard fail (fix + redeploy + rerun); copy/icon misses are recorded and fixed in the follow-up PR.
