# MoonBase Storage rules tests

Standalone suite using `@firebase/rules-unit-testing` against the Firebase Storage Emulator.
Does not use Flutter / FVM.

## Prerequisites

- Node.js ≥ 18
- Java 21+ on `PATH` (Storage emulator). On many Flutter Windows machines, Android Studio’s JBR works:
  `C:\Program Files\Android\Android Studio\jbr`
- From repo: `firebase.json` storage + emulators block + root `storage.rules`

`firebase-tools` is installed as a local devDependency.

## Install (once)

```powershell
cd "c:\Users\pdelu\App Dev\MoonBase Skeleton\moonbase_skeleton\storage\tests"
npm install
```

## Run

Preferred on Windows (sets `JAVA_HOME` to Android Studio JBR if `java` is missing):

```powershell
cd "c:\Users\pdelu\App Dev\MoonBase Skeleton\moonbase_skeleton\storage\tests"
.\run-tests.ps1
```

Or, if `java -version` already works:

```powershell
cd "c:\Users\pdelu\App Dev\MoonBase Skeleton\moonbase_skeleton\storage\tests"
npm.cmd test
```

This starts the Storage emulator (`127.0.0.1:9199`), runs Jest `--runInBand`, then shuts the emulator down.

## Coverage

Allow: signed-in upload under `bases/{baseId}/media/{fileName}` (small image/jpeg); signed-in read.

Deny: anonymous upload/read; oversized (≥ 10 MB); non-image content-type; otherwise-valid write outside media path; signed-in delete (MVP default-deny).
