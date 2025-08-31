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

## Testing Strategy

### Test Structure
- **Unit Tests**: `test/models/`, `test/services/` - Test individual components in isolation
- **Functional Tests**: `test/functional_test.dart` - Test complete workflows and integrations
- **Widget Tests**: `test/widget_test.dart` - Test UI components
- **Integration Tests**: `test/functional_test.dart` - End-to-end feature testing

### Running Tests
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/functional_test.dart

# Run with verbose output
flutter test --verbose

# Run with coverage
flutter test --coverage
```

### Functional Testing Approach
The functional tests use **SharedPreferences mocking** to test the complete data flow:

```dart
setUpAll(() async {
  // Initialize SharedPreferences with mock data
  SharedPreferences.setMockInitialValues({});
  prefs = await SharedPreferences.getInstance();
  
  // Setup mock current user
  await prefs.setString('mb.currentUser', 'testuser');
  await prefs.setString('mb.users', jsonEncode({
    'testuser': jsonEncode({
      'userId': testUserId,
      'nickname': 'testuser',
    })
  }));
});
```

### Test Data Management
- Each test gets a clean SharedPreferences instance
- Mock data is reset between tests to ensure isolation
- Use `setUp()` and `tearDown()` for proper cleanup

---

## Data Layer Patterns

### JSON Encoding/Decoding Pattern
**CRITICAL**: Avoid double JSON encoding in repository implementations.

#### ❌ Wrong Pattern (Causes Silent Failures)
```dart
// Storage
bases[baseId] = base.toJson(); // Returns Map<String, dynamic>

// Retrieval - WRONG!
return Base.fromJson(jsonEncode(baseJson)); // Double encoding!
```

#### ✅ Correct Pattern
```dart
// Storage
bases[baseId] = base.toJson(); // Returns Map<String, dynamic>

// Retrieval - CORRECT!
return Base.fromJson(baseJson); // Use Map directly
```

### Repository Implementation Guidelines
1. **Storage**: Use `model.toJson()` to convert to `Map<String, dynamic>`
2. **Retrieval**: Pass the `Map<String, dynamic>` directly to `Model.fromJson()`
3. **Error Handling**: Wrap JSON operations in try-catch blocks
4. **Validation**: Always validate data before returning from repositories

### SharedPreferences Key Structure
```
mb.bases       : { baseId : <Base JSON> }
mb.members     : { baseId : [<BaseMember JSON>] }
mb.userBases   : { userId : [baseId] }
mb.currentUser : "username"
mb.users       : { username : <User JSON> }
```

---

## Debugging Tips

### Common Issues
1. **"Base not found" errors**: Usually indicate JSON encoding issues
2. **Empty lists returned**: Check for silent JSON parsing failures
3. **Test isolation problems**: Ensure SharedPreferences is properly mocked

### Debugging Steps
1. Add temporary debug prints to trace data flow
2. Check SharedPreferences content during tests
3. Verify JSON structure matches expected format
4. Use `flutter test --verbose` for detailed output

### Performance Considerations
- Avoid excessive JSON encoding/decoding in loops
- Consider caching frequently accessed data
- Use efficient data structures for large datasets

---

## General Best Practices

- Use PR templates and GitHub Actions CI for consistent reviews & tests.
- Avoid upgrading Flutter during MVP unless blocked; upgrade after milestone.
- Document setup (FVM, SDK path, workflow) in README for clarity.
- **Always run tests before committing changes**
- **Test both success and failure scenarios**
- **Use meaningful test names that describe the behavior being tested**

---

**End of Guide**
