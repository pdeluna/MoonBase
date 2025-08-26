# MoonBase Development Guide

This document summarizes the core Git/GitHub workflow, Flutter practices, and project conventions for MoonBase.

---

## GitHub & Git Workflow

- Use SSH keys for authentication (stored in `C:\Users\<you>\.ssh`). Add public key (`.pub`) in GitHub Settings → SSH and GPG Keys.
- Daily dev cycle: **pull main → branch off → commit in small units → push branch → open Pull Request → squash+merge**.
- Branch naming convention: `feat/`, `fix/`, `chore/`, `docs/`, `refactor/`.
- First push of a branch: `git push -u origin <branch>` → afterwards: `git push`.
- Use `git stash push/pop` to save WIP when switching tasks.

---

## FVM (Flutter Version Management)

- Install via Dart pub. Add FVM bin folder to Windows PATH.
- Pin SDK per project with:
  ```powershell
  fvm install stable
  fvm use stable --pin
  ```
- Run commands prefixed with `fvm` (e.g., `fvm flutter run`).
- Configure Cursor/VS Code settings:
  ```json
  {
    "dart.flutterSdkPath": ".fvm/flutter_sdk",
    "dart.sdkPath": ".fvm/flutter_sdk/bin/cache/dart-sdk"
  }
  ```
- Keeps SDK consistent across environments; avoids breaking upgrades mid‑MVP.

---

## Flutter Development Basics

- Run app: `fvm flutter run (-d <device-id>)`.
- List devices: `fvm flutter devices`.
- Terminal commands while running:
  - `r` → hot reload
  - `R` → hot restart
  - `q` → quit
- Run `flutter pub get` only after dependency changes (`pubspec.yaml` edits).
- Daily dev flow:
  1. Sync main (`git checkout main && git pull --rebase origin main`)
  2. Create a feature branch
  3. Commit small, focused changes
  4. Run analyzer/tests before push
  5. Push and open PR

---

## General Best Practices

- Keep `.gitignore` in project root; don’t mix with `.ssh` keys.
- Use PR templates and GitHub Actions CI for consistent reviews & tests.
- Avoid upgrading Flutter during MVP unless blocked; upgrade after milestone.
- Document setup (FVM, SDK path, workflow) in README for clarity.

---

**End of Guide**
