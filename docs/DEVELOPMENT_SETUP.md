# MoonBase — Development Setup

A professional-grade onboarding guide for new contributors (especially junior developers) joining the MoonBase Flutter project. This document covers everything you need from a clean machine to your first merged pull request. Pairs with the broader workflow notes in [`DEV_GUIDE.md`](DEV_GUIDE.md) and the Phase 3 feature spec in [`PHASE3_POSTS_STORIES_REACTIONS_BLUEPRINT.md`](PHASE3_POSTS_STORIES_REACTIONS_BLUEPRINT.md).

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [VS Code / Cursor Environment Setup](#2-vs-code--cursor-environment-setup)
   - 2.1 [Required extensions](#21-required-extensions)
   - 2.2 [Recommended extensions](#22-recommended-extensions)
   - 2.3 [Workspace settings (`.vscode/settings.json`)](#23-workspace-settings-vscodesettingsjson)
   - 2.4 [Recommended launch & tasks configuration](#24-recommended-launch--tasks-configuration)
   - 2.5 [Why Prettier and ESLint do not apply here](#25-why-prettier-and-eslint-do-not-apply-here)
3. [Dependency Setup](#3-dependency-setup)
   - 3.1 [Clone the repository](#31-clone-the-repository)
   - 3.2 [Pin the Flutter SDK with FVM](#32-pin-the-flutter-sdk-with-fvm)
   - 3.3 [Install Dart/Flutter dependencies](#33-install-dartflutter-dependencies)
   - 3.4 [Environment variables (`.env.example`)](#34-environment-variables-envexample)
   - 3.5 [Platform permissions for Phase 3 media](#35-platform-permissions-for-phase-3-media)
   - 3.6 [Verify your local build](#36-verify-your-local-build)
4. [Git Hygiene & Workflow Rules](#4-git-hygiene--workflow-rules)
   - 4.1 [Branch naming convention](#41-branch-naming-convention)
   - 4.2 [Semantic commit messages (Conventional Commits)](#42-semantic-commit-messages-conventional-commits)
   - 4.3 [Pull request expectations](#43-pull-request-expectations)
   - 4.4 [Keeping your branch rebased with `main`](#44-keeping-your-branch-rebased-with-main)
   - 4.5 [Resolving merge conflicts safely](#45-resolving-merge-conflicts-safely)
5. [Daily Developer Checklist](#5-daily-developer-checklist)
6. [Troubleshooting](#6-troubleshooting)
7. [Further Reading](#7-further-reading)

---

## 1. Prerequisites

| Tool | Version | Purpose |
| --- | --- | --- |
| **Git** | ≥ 2.40 | Source control |
| **Flutter SDK** | ≥ 3.22 (managed via FVM, see Section 3.2) | App framework |
| **Dart SDK** | ≥ 3.3 (bundled with Flutter) | Language toolchain |
| **FVM** (Flutter Version Management) | latest | Pin the project SDK so every contributor is on the same version |
| **VS Code** or **Cursor** | latest | Recommended IDE (this guide assumes one of these) |
| **Android Studio** *or* **Xcode** *or* **VS Studio Build Tools** | latest stable | Platform toolchains for whichever target you build |
| **GitHub CLI** (`gh`) | ≥ 2.40, optional | Quality-of-life for opening PRs from the terminal |

> **Prerequisite check:** before continuing, run `git --version`, `flutter --version` (or `fvm flutter --version`), and `code --version`. If any of these fail, install the missing tool before touching the repository.

> **Operating system note:** this project is developed primarily on Windows. PowerShell snippets are provided where the syntax differs from a POSIX shell. macOS/Linux contributors can run the equivalent in `bash`/`zsh` — substitute `\` line continuations for backticks (`` ` ``) and use forward slashes in paths.

---

## 2. VS Code / Cursor Environment Setup

The repository does **not** ship a `.vscode/` folder by default (it is intentionally left out of version control — see [`.gitignore`](../.gitignore) line 21–24). Each contributor sets up their own. The settings below match the project's analyzer configuration in [`analysis_options.yaml`](../analysis_options.yaml).

### 2.1 Required extensions

Install these. Without them, the editor will not match the project's lint and format rules and CI will reject your PR.

| Extension | Marketplace ID | What it gives you |
| --- | --- | --- |
| **Dart** | `Dart-Code.dart-code` | Language server, syntax highlighting, debugging, `dart format` integration |
| **Flutter** | `Dart-Code.flutter` | Project scaffolding, hot reload, device picker, widget inspector |
| **GitLens — Git supercharged** | `eamodio.gitlens` | Inline blame, file history, branch comparison, deep PR context |
| **EditorConfig for VS Code** | `EditorConfig.EditorConfig` | Enforces line endings, indent style, and trim-trailing-whitespace across editors |

### 2.2 Recommended extensions

Strongly suggested but not enforced.

| Extension | Marketplace ID | What it gives you |
| --- | --- | --- |
| **Error Lens** | `usernamehw.errorlens` | Inlines analyzer errors next to the offending line — invaluable when learning the strict-cast rules |
| **Awesome Flutter Snippets** | `Nash.awesome-flutter-snippets` | Snippets for `StatelessWidget`, `Consumer`, `StateNotifier`, etc. |
| **Pubspec Assist** | `jeroen-meijer.pubspec-assist` | Add dependencies via command palette with version lookup |
| **Better Comments** | `aaron-bond.better-comments` | Color-codes `TODO`, `FIXME`, `NOTE` comments |
| **Markdown All in One** | `yzhang.markdown-all-in-one` | TOC generation and formatting for the docs you'll write |
| **Mermaid Preview** | `bierner.markdown-mermaid` | Renders the mermaid diagrams used in [`PHASE3_POSTS_STORIES_REACTIONS_BLUEPRINT.md`](PHASE3_POSTS_STORIES_REACTIONS_BLUEPRINT.md) |
| **YAML** | `redhat.vscode-yaml` | Schema-aware editing for `pubspec.yaml` and `analysis_options.yaml` |

> **One-shot install (PowerShell):**
>
> ```powershell
> code --install-extension Dart-Code.dart-code `
>      --install-extension Dart-Code.flutter `
>      --install-extension eamodio.gitlens `
>      --install-extension EditorConfig.EditorConfig `
>      --install-extension usernamehw.errorlens `
>      --install-extension Nash.awesome-flutter-snippets `
>      --install-extension yzhang.markdown-all-in-one `
>      --install-extension bierner.markdown-mermaid `
>      --install-extension redhat.vscode-yaml
> ```
>
> On macOS/Linux replace the backticks (`` ` ``) with backslashes (`\`).

### 2.3 Workspace settings (`.vscode/settings.json`)

Create a file at `moonbase_skeleton/.vscode/settings.json` with the contents below. These settings match the project lint rules in [`analysis_options.yaml`](../analysis_options.yaml) (strict-casts, strict-inference, strict-raw-types) and the FVM-pinned SDK pattern documented in [`DEV_GUIDE.md`](DEV_GUIDE.md).

```json
{
  "// FVM": "Point the Dart/Flutter extension at the project-pinned SDK so every contributor is on the same version.",
  "dart.flutterSdkPath": ".fvm/flutter_sdk",
  "dart.sdkPath": ".fvm/flutter_sdk/bin/cache/dart-sdk",

  "// Formatting": "Format on save and on paste. dart format ships with the SDK; no Prettier needed for Dart.",
  "editor.formatOnSave": true,
  "editor.formatOnPaste": true,
  "editor.defaultFormatter": "Dart-Code.dart-code",
  "[dart]": {
    "editor.defaultFormatter": "Dart-Code.dart-code",
    "editor.formatOnSave": true,
    "editor.rulers": [80],
    "editor.selectionHighlight": false,
    "editor.suggestSelection": "first",
    "editor.tabCompletion": "onlySnippets",
    "editor.wordBasedSuggestions": "off"
  },

  "// Analyzer": "Surface errors aggressively. The project uses strict-casts/inference/raw-types.",
  "dart.lineLength": 100,
  "dart.previewFlutterUiGuides": true,
  "dart.previewFlutterUiGuidesCustomTracking": true,
  "dart.showInspectorNotificationsForWidgetErrors": true,
  "dart.warnWhenEditingFilesOutsideWorkspace": true,
  "dart.runPubGetOnPubspecChanges": "always",

  "// Editor hygiene": "Match EditorConfig + project conventions.",
  "files.insertFinalNewline": true,
  "files.trimFinalNewlines": true,
  "files.trimTrailingWhitespace": true,
  "files.eol": "\n",
  "editor.tabSize": 2,
  "editor.insertSpaces": true,
  "editor.detectIndentation": false,

  "// Search": "Skip generated and platform output to keep search fast.",
  "search.exclude": {
    "**/.dart_tool": true,
    "**/.fvm": true,
    "**/build": true,
    "**/.pub-cache": true,
    "**/coverage": true,
    "**/ios/Pods": true,
    "**/android/.gradle": true,
    "**/windows/flutter/ephemeral": true,
    "**/macos/Flutter/ephemeral": true
  },
  "files.watcherExclude": {
    "**/.dart_tool/**": true,
    "**/.fvm/**": true,
    "**/build/**": true,
    "**/coverage/**": true
  },

  "// Markdown": "TOC and mermaid render nicely in the docs.",
  "[markdown]": {
    "editor.wordWrap": "on",
    "editor.quickSuggestions": { "comments": "off", "strings": "off", "other": "on" }
  },

  "// Git": "Keep history clean and rebases predictable.",
  "git.autofetch": true,
  "git.pruneOnFetch": true,
  "git.confirmSync": false,
  "git.enableSmartCommit": false,
  "git.rebaseWhenSync": true,

  "// Terminal": "Default to PowerShell on Windows; harmless on other OSes.",
  "terminal.integrated.defaultProfile.windows": "PowerShell"
}
```

> **Important:** add `.vscode/settings.json` to your **local** workspace only if your team chooses not to commit it. The project's `.gitignore` currently leaves `.vscode/` un-ignored (line 21–24 are commented out), so committing a sanitized `settings.json` is fine and is in fact recommended so every contributor lands on the same baseline.

Also create an `.editorconfig` at the repo root (`moonbase_skeleton/.editorconfig`) if one does not already exist:

```ini
root = true

[*]
charset = utf-8
end_of_line = lf
indent_style = space
indent_size = 2
insert_final_newline = true
trim_trailing_whitespace = true

[*.{md,markdown}]
trim_trailing_whitespace = false
```

### 2.4 Recommended launch & tasks configuration

Create `moonbase_skeleton/.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "moonbase (debug)",
      "type": "dart",
      "request": "launch",
      "program": "lib/main.dart"
    },
    {
      "name": "moonbase (profile)",
      "type": "dart",
      "request": "launch",
      "program": "lib/main.dart",
      "flutterMode": "profile"
    },
    {
      "name": "moonbase (release)",
      "type": "dart",
      "request": "launch",
      "program": "lib/main.dart",
      "flutterMode": "release"
    }
  ]
}
```

And `moonbase_skeleton/.vscode/tasks.json`:

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Flutter: pub get",
      "type": "shell",
      "command": "fvm flutter pub get",
      "problemMatcher": []
    },
    {
      "label": "Flutter: analyze",
      "type": "shell",
      "command": "fvm flutter analyze",
      "group": "test",
      "problemMatcher": ["$dart-analyze"]
    },
    {
      "label": "Flutter: format (check)",
      "type": "shell",
      "command": "fvm dart format --output=none --set-exit-if-changed .",
      "problemMatcher": []
    },
    {
      "label": "Flutter: test",
      "type": "shell",
      "command": "fvm flutter test",
      "group": { "kind": "test", "isDefault": true },
      "problemMatcher": []
    },
    {
      "label": "Pre-push: full gate",
      "dependsOrder": "sequence",
      "dependsOn": ["Flutter: format (check)", "Flutter: analyze", "Flutter: test"],
      "problemMatcher": []
    }
  ]
}
```

> **Tip:** bind `Pre-push: full gate` to a keybinding (`Ctrl+Shift+P` → "Preferences: Open Keyboard Shortcuts (JSON)") so you can run the full local CI check with one keystroke before every `git push`.

### 2.5 Why Prettier and ESLint do not apply here

Junior developers coming from JavaScript or TypeScript projects often ask where to add Prettier and ESLint. **They are not used in this repository** because the project is Dart/Flutter, which has built-in equivalents:

| JS/TS tool | Dart/Flutter equivalent | Where it lives |
| --- | --- | --- |
| **Prettier** | `dart format` (ships with the Dart SDK) | Run via the Dart extension on save, or `fvm dart format .` on the CLI |
| **ESLint** | `dart analyze` driven by `package:flutter_lints` | Configured in [`analysis_options.yaml`](../analysis_options.yaml) |
| **`.eslintrc`** | [`analysis_options.yaml`](../analysis_options.yaml) | Already in the repo with strict-casts, strict-inference, strict-raw-types, and ~25 additional lints enabled |
| **`tsconfig.json`** strict flags | The `analyzer.language.strict-*` block | Same file |
| **Husky / lint-staged pre-commit hooks** | Optional `.git/hooks/pre-commit` running `dart format --set-exit-if-changed` + `flutter analyze` + `flutter test` | Suggested but not required; the `Pre-push: full gate` VS Code task is the cross-platform substitute |

Do not install Prettier, ESLint, or any Node-based formatting tool inside this repository. They will silently fight the Dart formatter.

---

## 3. Dependency Setup

### 3.1 Clone the repository

```powershell
git clone git@github.com:<org>/moonbase.git
cd moonbase\moonbase_skeleton
```

> **Warning:** clone over **SSH**, not HTTPS, so pushes work without a personal access token. SSH keys live in `C:\Users\<you>\.ssh` on Windows or `~/.ssh` on macOS/Linux. Add your `id_ed25519.pub` to GitHub under **Settings → SSH and GPG Keys** before cloning — see the "GitHub & Git Workflow" section of [`DEV_GUIDE.md`](DEV_GUIDE.md).

### 3.2 Pin the Flutter SDK with FVM

The project pins its Flutter SDK via [FVM](https://fvm.app/). This guarantees every contributor and CI runner uses the **same** SDK version, so "works on my machine" bugs caused by SDK drift cannot happen.

```powershell
dart pub global activate fvm
fvm install stable
fvm use stable --pin
fvm doctor
```

Add the FVM bin directory to your PATH (Windows: System Properties → Environment Variables; macOS/Linux: append to `~/.zshrc` or `~/.bashrc`). Then verify:

```powershell
fvm flutter --version
fvm dart --version
```

> **Warning:** do **not** run a bare `flutter` command from inside the project once FVM is set up. You will pick up your system-wide SDK instead of the pinned one. Always prefix with `fvm` (or use the VS Code tasks above, which already do).

### 3.3 Install Dart/Flutter dependencies

```powershell
fvm flutter pub get
```

Verify the dependency tree is clean:

```powershell
fvm flutter pub outdated
fvm flutter pub deps --no-dev --style=compact
```

> **Note:** the project deliberately keeps dependencies minimal (see [`pubspec.yaml`](../pubspec.yaml) line 19). Before adding a new package, open an issue or ask in the team channel. New dependencies require a PR review specifically for the dependency change.

The full dependency list at the time of writing:

| Runtime | Why |
| --- | --- |
| `flutter_riverpod ^2.5.1` | State management (controllers and providers) |
| `go_router ^14.2.0` | Declarative routing |
| `shared_preferences ^2.3.2` | Local key-value persistence (the L1 cache layer) |
| `uuid ^4.5.1` | Client-generated entity IDs |
| `image_picker ^1.1.2` | OS camera + gallery (Phase 3) |
| `video_player ^2.9.2` | Video playback (Phase 3) |
| `path_provider ^2.1.4` | App documents directory for `LocalFileMediaStorage` (Phase 3) |
| `mime ^1.0.5` | MIME sniffing for media validation (Phase 3) |
| `flutter_image_compress ^2.3.0` | Optional compression to enforce media size caps (Phase 3) |

| Dev | Why |
| --- | --- |
| `flutter_lints ^4.0.0` | Lint rule package |
| `mocktail ^1.0.3` | Mocking framework for unit tests |
| `fake_async ^1.3.1` | Deterministic time control for stream/TTL tests |
| `flutter_launcher_icons ^0.13.1` | App icon generation |

### 3.4 Environment variables (`.env.example`)

> **Status note:** Phase 3 is **local-only** — see Phase 3 DoD constraint #1 in [`PHASE3_DOD_ACTION_LIST.md`](PHASE3_DOD_ACTION_LIST.md). The app currently does not read any environment variables. The `.env.example` pattern below is set up now so that when Phase 4 cloud sync lands (see Section 4 of [`PHASE3_POSTS_STORIES_REACTIONS_BLUEPRINT.md`](PHASE3_POSTS_STORIES_REACTIONS_BLUEPRINT.md)), backend URLs and feature flags drop into an established slot.

Create a file at `moonbase_skeleton/.env.example` and commit it. This file documents **every** environment variable the app understands, with safe placeholder values:

```dotenv
# .env.example — copy to .env.local and fill in your own values. Do NOT commit .env.local.
# Phase 3 is local-only; these variables are unused today but reserved for Phase 4.

# --- Backend (Phase 4) ---
MB_API_BASE_URL=https://api.moonbase.local
MB_REALTIME_URL=wss://api.moonbase.local/v1/realtime
MB_MEDIA_SIGNED_UPLOAD_PATH=/v1/bases/{baseId}/media:signedUpload

# --- Feature flags ---
MB_ENABLE_REMOTE_SYNC=false
MB_ENABLE_STORIES_ARCHIVE_TOGGLE=true

# --- Tooling / debug ---
MB_LOG_LEVEL=info        # one of: trace, debug, info, warn, error
MB_FAKE_LATENCY_MS=0     # inject artificial latency in dev for testing AsyncValue.loading states
```

Each developer copies the example into a real, **gitignored** local file:

```powershell
Copy-Item .env.example .env.local
```

Add the local file to `.gitignore` (it is **not** there yet — add the lines below to [`.gitignore`](../.gitignore)):

```gitignore
# Local environment files (developer-specific; never commit).
.env
.env.local
.env.*.local
```

> **Security warning:** never commit a populated `.env`, `.env.local`, or any file containing real credentials, tokens, or signed URLs. If you accidentally commit one:
>
> 1. Rotate the credential **immediately** (assume it is compromised the moment it touched the remote).
> 2. Remove the file from history with `git filter-repo` or BFG.
> 3. Force-push the rewritten history with your team's explicit consent.
>
> Detection is built into most CI providers via `gitleaks` or `trufflehog` — consider adding one to the pipeline before Phase 4 ships.

**Consuming `.env` values in Flutter:** the idiomatic, build-tool-native pattern is `--dart-define` plus a checked-in `dart_define.json` (gitignored for local overrides). When Phase 4 lands, the wiring will look like this — already documented here so the junior knows the target shape:

```powershell
# Read .env.local, expand each KEY=VALUE pair into a --dart-define flag, then run.
fvm flutter run `
  --dart-define=MB_API_BASE_URL=https://api.moonbase.local `
  --dart-define=MB_ENABLE_REMOTE_SYNC=false
```

Inside Dart, values are read via `const String.fromEnvironment('MB_API_BASE_URL')`. This is build-time-constant and tree-shakeable — no runtime `.env` parsing required, which is why we do **not** add `flutter_dotenv` to `pubspec.yaml`.

### 3.5 Platform permissions for Phase 3 media

If you are working on the media, stories, or posts slices, you must wire OS permissions. Follow the checklist in [`PHASE3_DOD_ACTION_LIST.md`](PHASE3_DOD_ACTION_LIST.md) Section 0.1.3:

- **Android** — add to `android/app/src/main/AndroidManifest.xml`: `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`, `CAMERA`, `RECORD_AUDIO`.
- **iOS** — add to `ios/Runner/Info.plist`: `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`, `NSMicrophoneUsageDescription`.
- **macOS** (if targeted) — add camera + microphone + user-selected files entitlements.

> **Warning:** denying any of these on first OS prompt must surface a `PermissionDeniedFailure` (see [`lib/core/failure.dart`](../lib/core/failure.dart)) with a UX affordance to open OS settings. Silent permission failures are a Phase 3 DoD blocker.

### 3.6 Verify your local build

Run the **full local gate** that CI also runs. If any of these fail, fix them before pushing.

```powershell
# 1. Pull-clean dependencies (no stale lockfile state)
fvm flutter pub get

# 2. Formatter (fails if any file would be changed)
fvm dart format --output=none --set-exit-if-changed .

# 3. Analyzer (zero warnings policy on lib/ and test/)
fvm flutter analyze

# 4. Unit & widget tests (must pass)
fvm flutter test

# 5. Smoke build for at least one target platform
fvm flutter build apk --debug      # Android
# or
fvm flutter build ios --debug --no-codesign   # iOS, macOS only
# or
fvm flutter build windows --debug  # Windows
```

> **Definition of "green":** all five steps exit with code 0. The VS Code task `Pre-push: full gate` (defined in Section 2.4) chains steps 2–4 into one command.

---

## 4. Git Hygiene & Workflow Rules

These rules are non-negotiable. They exist so reviewers spend their time on code, not on cleaning up your branch.

### 4.1 Branch naming convention

The project already follows a short-prefix convention documented in [`DEV_GUIDE.md`](DEV_GUIDE.md). **Use it.** Do not invent new prefixes.

| Prefix | When to use it | Example |
| --- | --- | --- |
| `feat/` | New user-facing capability | `feat/stories-feed-controller` |
| `fix/` | Bug fix that does not change public API | `fix/chat-scroll-jumps-on-new-message` |
| `chore/` | Tooling, dependency bumps, CI tweaks | `chore/bump-flutter-3.22` |
| `refactor/` | Code restructuring with no behavior change | `refactor/post-card-vm-extraction` |
| `docs/` | Documentation-only changes | `docs/development-setup` |
| `test/` | Test-only additions or fixes | `test/story-expiry-sweep-edge-cases` |
| `spike/` | Time-boxed exploration, not for merge | `spike/in-app-camera-feasibility` |

**Rules:**

- Use kebab-case after the slash. **No** `featureUnderscoreCamel`.
- Reference a single concern. If the branch starts touching unrelated code, open a second branch.
- Include a Slice or DoD section reference when applicable: `feat/slice-c-post-card`, `feat/dod-3-2-3-reaction-data-source`.

> **Warning:** if you find yourself naming a branch `feat/misc`, `fix/stuff`, or `chore/cleanup`, stop and split it. Reviewers cannot reason about a "miscellaneous" diff.

### 4.2 Semantic commit messages (Conventional Commits)

Every commit message follows the [Conventional Commits](https://www.conventionalcommits.org/) format:

```
<type>(<scope>): <subject>

<body>

<footer>
```

| Field | Rule |
| --- | --- |
| `<type>` | One of `feat`, `fix`, `chore`, `refactor`, `docs`, `test`, `style`, `perf`, `build`, `ci` |
| `<scope>` | The affected feature module, lower-case (`stories`, `posts`, `reactions`, `chat`, `bases`, `media`, `auth`, `profile`, `core`) — or `*` if it touches multiple |
| `<subject>` | Imperative, present tense, ≤ 72 chars, **no trailing period** |
| `<body>` | Optional. Explain **why**, not what. Wrap at 80 chars |
| `<footer>` | Optional. Issue refs (`Refs #42`), breaking changes (`BREAKING CHANGE: ...`) |

**Examples that match the project's existing history:**

```text
feat(stories): implement StoryFeedController with AsyncValue<List<Story>>

Mirrors ChatController; subscribes to StoryRepository.streamActive and
filters expired stories on each tick. See PHASE3_DOD_ACTION_LIST.md Section 2.2.6.

Refs #87
```

```text
fix(chat): prevent double-encode on MessageModel persistence

The repository was calling jsonEncode on a Map that fromJson then re-decoded,
producing silent String-vs-Map mismatches. Removed the extra encode.

Refs DEV_GUIDE.md "Data Layer Patterns" section
```

```text
refactor(reactions): extract ReactionGroup from PostCardVM

No behavior change. Sets up the StoryViewerVM to reuse the same grouping.
```

```text
docs(setup): add DEVELOPMENT_SETUP.md
```

**Anti-patterns — reject in PR review:**

- `WIP`, `fix stuff`, `more changes`, `final` — meaningless to a reviewer reading history six months later.
- `Fixed bug` — what bug?
- A 400-line diff in one commit — break it up; one logical concern per commit.

> **Tip:** if your PR's commit history is messy after you finish a feature, run `git rebase -i origin/main` and squash/fix-up locally before requesting review. CI does not care; your reviewer does.

### 4.3 Pull request expectations

Open a PR as soon as you have something pushable, even in **Draft** status. Early visibility beats a single-PR-end-of-week dump.

**PR title** uses the same Conventional Commits format as commits: `feat(reactions): wire ReactionController into PostCard`.

**PR description template** — copy this into every PR:

```markdown
## Summary

<1–3 sentences. What does this change and why?>

## Phase 3 DoD reference

<Cite the relevant section, e.g. PHASE3_DOD_ACTION_LIST.md Section 2.2.6 or
PHASE3_POSTS_STORIES_REACTIONS_BLUEPRINT.md Section 2.3.>

## Screenshots / recordings

<Required for any presentation change. Drag-and-drop into the PR.>

## Test plan

- [ ] `fvm dart format --set-exit-if-changed .` clean
- [ ] `fvm flutter analyze` clean
- [ ] `fvm flutter test` passes
- [ ] Manual smoke: <list the user-visible flows you exercised>
- [ ] Base isolation verified (if touching persistence)
- [ ] App-restart re-resolves state (if touching MediaStorage or SharedPreferences)

## Risks / follow-ups

<Anything the reviewer should look at extra-carefully, or anything deferred
to a follow-up PR.>
```

**Reviewer expectations:**

- At least **one** approval from a project maintainer before merge.
- All CI checks green.
- Resolve every reviewer comment with either a code change or an explicit "won't fix because …" reply. Do not silently dismiss comments.
- Merge strategy: **squash and merge**. The squash commit message must itself be a valid Conventional Commit.

> **Warning:** do not merge your own PR unless explicitly granted that permission for the repository. Always wait for a maintainer to merge.

### 4.4 Keeping your branch rebased with `main`

We rebase, we do not merge `main` into feature branches. Rebasing keeps history linear and bisectable.

**Daily routine:**

```powershell
# Make sure your local main is current
git checkout main
git pull --rebase origin main

# Switch back to your feature branch
git checkout feat/stories-feed-controller

# Rebase onto the latest main
git rebase main

# Resolve any conflicts (see Section 4.5), then continue
git rebase --continue

# Force-push your rewritten branch (use --force-with-lease for safety)
git push --force-with-lease
```

> **Warning:** never `git push --force` to a branch other people may have pulled. Always use `--force-with-lease`, which refuses the push if anyone else has added commits since your last fetch. This single habit prevents the most common "I lost my commits" disaster.

> **Important:** do **not** `git merge main` into your feature branch. That creates merge commits that pollute the history and make squash-merging the final PR messy. If you accidentally do, run `git reset --hard origin/<your-branch>@{1}` to undo, then rebase instead.

### 4.5 Resolving merge conflicts safely

```powershell
# During a rebase, conflicts are surfaced one commit at a time.
# Resolve files in your editor (look for <<<<<<< markers), then:
git add <resolved-files>
git rebase --continue

# If the situation is hopeless and you want to bail:
git rebase --abort   # returns you to the pre-rebase state
```

When a conflict is non-trivial, prefer to **re-author the change on top of `main`**: copy the intent of your patch into a fresh branch off the current `main`, rather than fighting `git mergetool`. This is faster and yields a cleaner diff.

> **Tip:** GitLens (installed in Section 2.1) shows the "blame" of each conflict marker, which usually identifies whose change you are conflicting with and why. Talk to that person before guessing at the resolution.

---

## 5. Daily Developer Checklist

Pin this to your monitor:

**Before you start coding:**

```powershell
git checkout main
git pull --rebase origin main
git checkout -b feat/<short-kebab-description>
fvm flutter pub get
```

**While you code:**

- Hot reload (`r` in the running app's terminal) for cosmetic and state-preserving changes.
- Hot restart (`R`) when you change provider wiring or top-level state.
- Run `fvm flutter test test/features/<feature>/` frequently — the per-feature run is fast.

**Before you commit:**

```powershell
fvm dart format .
fvm flutter analyze
fvm flutter test
git add <only the files you intended>
git commit -m "feat(<scope>): <subject>"
```

**Before you push:**

```powershell
git fetch origin
git rebase origin/main
git push --force-with-lease   # only --force-with-lease, never plain --force
```

**Before you mark a draft PR ready for review:**

- [ ] PR description filled in per Section 4.3 template.
- [ ] All CI checks green.
- [ ] Screenshots / recordings attached for any UI change.
- [ ] Self-review: open the PR's **Files changed** tab and read your own diff start to finish. You will catch your own bugs.

---

## 6. Troubleshooting

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| `flutter: command not found` after FVM install | FVM bin not on PATH | Add `$HOME/fvm/default/bin` (or Windows equivalent) to PATH; restart shell |
| Analyzer complains about strict-cast on existing code | Editor is using system Dart SDK, not the FVM-pinned one | Verify `.vscode/settings.json` has `dart.flutterSdkPath: ".fvm/flutter_sdk"`; restart the Dart Analysis Server (`Ctrl+Shift+P` → "Dart: Restart Analysis Server") |
| `flutter pub get` hangs on Windows | Antivirus scanning `.pub-cache` | Exclude `%LOCALAPPDATA%\Pub\Cache` from real-time scanning |
| Tests pass locally but fail in CI | Different SDK version | Ensure FVM is pinned (`fvm use stable --pin`) and that CI uses the same pin |
| Media files vanish after app reinstall | Storage key was absolute instead of relative | See [`PHASE3_POSTS_STORIES_REACTIONS_BLUEPRINT.md`](PHASE3_POSTS_STORIES_REACTIONS_BLUEPRINT.md) Section 2.4 cache-key invariants; the key must be `<baseId>/<uuid>.<ext>` |
| Rebase produces hundreds of conflicts | You merged `main` into your branch at some point | Re-author the change on top of a fresh branch off `main` (see Section 4.5) |
| `git push --force-with-lease` rejected | Someone else pushed to your branch (or you pulled and forgot) | `git pull --rebase` first, then push again |
| VS Code does not auto-format on save | Default formatter not set to Dart | Re-check the `[dart]` block in `.vscode/settings.json` (Section 2.3) |
| `dart format --set-exit-if-changed .` fails in CI but works locally | Line-ending mismatch (CRLF on Windows vs LF on Linux CI) | Confirm `.editorconfig` and `files.eol: "\n"` in settings; run `git config core.autocrlf false` |

If a problem is not in this table, search closed issues on the repository, then ask in the team channel with: the exact command run, the full error output, your OS and Flutter version (`fvm flutter --version`), and a link to the branch.

---

## 7. Further Reading

- [`README.md`](../README.md) — project overview, current phase status, and feature roadmap.
- [`DEV_GUIDE.md`](DEV_GUIDE.md) — original Flutter / Git workflow notes; this document supersedes its setup sections but the testing-strategy and JSON-encoding sections remain authoritative.
- [`REFACTOR_ARCHITECTURE.md`](REFACTOR_ARCHITECTURE.md) — 3-layer Clean Architecture overview.
- [`PHASE3_DOD_ACTION_LIST.md`](PHASE3_DOD_ACTION_LIST.md) — slice-by-slice checklist for the Phase 3 content features.
- [`PHASE3_POSTS_STORIES_REACTIONS_BLUEPRINT.md`](PHASE3_POSTS_STORIES_REACTIONS_BLUEPRINT.md) — locked architectural blueprint for Posts, Stories, and Reactions; cite section numbers in your PRs.
- [`MODEL_ARCHITECTURE.md`](MODEL_ARCHITECTURE.md) — entity and model conventions.
- [Effective Dart](https://dart.dev/effective-dart) — official Dart style guide; the project's lints derive from it.
- [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/) — full grammar for Section 4.2.
- [Flutter testing cookbook](https://docs.flutter.dev/cookbook/testing) — patterns the project uses for widget and unit tests.

---

*Last reviewed 2026-06-12. Update this document whenever the toolchain, lint config, dependencies, or workflow rules change — a setup guide that drifts from reality is worse than no guide at all.*
