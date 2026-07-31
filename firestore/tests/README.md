# MoonBase Firestore rules tests

Standalone suite using `@firebase/rules-unit-testing` against the Firebase Emulator.
Does not use Flutter / FVM.

## Prerequisites

- Node.js ≥ 18
- Java 21+ on `PATH` (Firestore emulator). On many Flutter Windows machines, Android Studio’s JBR works:
  `C:\Program Files\Android\Android Studio\jbr`
- From repo: `firebase.json` emulators block + root `firestore.rules`

`firebase-tools` is installed as a local devDependency.

## Install (once)

```powershell
cd "c:\Users\pdelu\Cursor Projects\moonbase\MoonBase\firestore\tests"
npm install
```

## Run

Preferred on Windows (sets `JAVA_HOME` to Android Studio JBR if `java` is missing):

```powershell
cd "c:\Users\pdelu\Cursor Projects\moonbase\MoonBase\firestore\tests"
.\run-tests.ps1
```

If PowerShell blocks `npm` / `firebase` (`.ps1` scripts disabled), either open a **new** terminal after:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

or call the `.cmd` shims directly (`npm.cmd test`, `firebase.cmd ...`). `run-tests.ps1` already uses `npm.cmd`.

Or, if `java -version` already works:

```powershell
cd "c:\Users\pdelu\Cursor Projects\moonbase\MoonBase\firestore\tests"
npm.cmd test
```

This starts the Firestore emulator (`127.0.0.1:8080`), runs Jest `--runInBand`, then shuts the emulator down.

## Coverage

Allow: owner-create, join (+1 self), leave (−1 self).

Deny (each uses `assertFails`): non-owner rename, joiner adds other uid, redeem past `maxUses`, redeem past `expiresAt`, non-member read base, non-member read messages, profile A writes B.

Also: contention/orphan demos justifying client `runTransaction` on redeem (see `docs/FIRESTORE_SCHEMA.md` Decisions & deferred).
