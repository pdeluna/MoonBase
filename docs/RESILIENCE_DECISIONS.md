# Resilience decisions

**Keep next to:** [`FIRESTORE_SCHEMA.md`](FIRESTORE_SCHEMA.md) (document shape), [`FIRESTORE_UPDATE_TRIGGERS.md`](FIRESTORE_UPDATE_TRIGGERS.md) (un-park triggers).

Hang / transport evidence and the decisions it locked. Not schema. Do not copy these numbers into comments without their **Conditions** column — a figure without conditions is not evidence.

---

## Provenance

These figures came from `DIAG_HANG` instrumentation removed on **2026-08-13**. Re-measuring requires re-adding equivalent logging (`DIAG_<TOPIC>`, `kDebugMode`, BEFORE/AFTER with `elapsedMs`) and re-running the scenarios. The code that produced them no longer exists.

---

## Device measurements

| Measurement | Value | Conditions | Justifies |
|-------------|-------|------------|-----------|
| `readProfile` cached-read latency | 63 / 597 / 10036 / 10053 / 14939 / 14948 ms | Blackhole + warm cache, cold channel. Every one a successful cached read. | `kGuardTimeout` = 20s, not 8s or 15s |
| Firestore online-state ceiling | 10182 / 10217 / 10325 ms | Blackhole, document get | Why `snapshots()` streams are not wrapped |
| Chat cached emission | 65 / 72 / 84 / 95 / 123 ms, `count=15` `isFromCache=true` | Blackhole + warm cache | R5 renders cache in <150ms |
| Cache→live window | ~117ms (#1 at 65ms → #2 at 182ms) | Good network, warm cache | 400ms banner delay ≈ 3.4× |
| Storage `-13030` | ~95s → ~20s | Blackhole, received photo tap | R2's before/after |
| Offline-send metadata | `isFromCache=true` `hasPendingWrites=true` | Blackhole + warm cache, text send | Why the freshness formula dropped `&& !hasPendingWrites` |

Storage ~95s is the **pre-R2** uncapped SDK default. After R2 (15s native `maxOperationRetryTime`, 20s `resolveTimeout`) the spinner ends at ~20s. A blackhole image check is hang vs instant cleartext `IOException`, not a duration.

---

## Network posture

**Home is the acceptance-test network.** It is dual-stack: two global IPv6 addresses `2604:3d0a:…` plus IPv4. That is the network that reproduced the Auth hang and against which the BoM 34.17.0 / Auth 24.2.0 bump was verified.

The library network is IPv4-only with link-local IPv6 only. It never reproduced the bug. A clean run on that network (or any IPv4-only path) is not evidence the hang is fixed.

---

## Red herrings

These appear on **healthy** runs. Do not chase them as the hang.

- Empty reCAPTCHA token (Firebase Auth logging; a successful sign-in prints it too).
- Play Services family (same category):
  - `FlagStore` / `Phenotype.API is not available`
  - `GoogleApiManager: Failed to get service from broker`
  - `SecurityException: Unknown calling package name 'com.google.android.gms'`

---

## Diagnostic naming (next hang session)

Copied from the executed [`DIAG_HANG_REVERT_PLAN.md`](DIAG_HANG_REVERT_PLAN.md) so a later delete of that procedure does not lose the convention.

| Rule | Meaning |
|------|---------|
| Prefix `DIAG_<TOPIC>` | One topic per prefix so a grep is a complete revert list. Examples: `DIAG_AUTH`, `DIAG_STORE`, `DIAG_SNAP`. |
| Always behind `kDebugMode` | `19a1e69` did not wrap; those prints can reach profile/release. New work must wrap. |
| BEFORE / AFTER with `elapsedMs` | Stopwatch at the operation (or at **subscription** for streams). Log every exit including throw. |
| Inventory in a revert doc before the session ends | Write it while measurements and commit hashes are still in working memory. |
| Per-subscription counters, not per-instance | A datasource-level timer survives “open base → back out → open again” and reports `#4` on a stale clock. |
| Cap noisy streams | Log emissions #1–#3 then stop. |
| Do not mix permanent fixture files into the throwaway commit | Harness/config in one commit, `DIAG_*` prints in another. |
| Metadata stays at the data-source boundary | `isFromCache` / `hasPendingWrites` for logs only. Domain freshness types are product, not throwaway. |
