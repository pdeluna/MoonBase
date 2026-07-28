# BaseSidebar Widget Test Suite Documentation

> **Deprecated.** This document describes tests for the legacy BaseSidebar. For the current implementation, see [REFACTOR_ARCHITECTURE.md](REFACTOR_ARCHITECTURE.md) and the bases feature under `lib/features/bases/`.

## Overview

The BaseSidebar widget test suite provides comprehensive testing coverage for the BaseSidebar component, ensuring reliable functionality across all states and interactions. The suite uses **mocktail** for improved performance and **behavior-driven testing** to verify actual widget behavior rather than implementation details.

## Test Suite Summary

### **🧪 Core Rendering Tests**
1. **`renders header correctly`** - Verifies the sidebar displays "My Bases" title and subtitle
2. **`renders action buttons`** - Confirms "Create Base" and "Join Base" buttons are present
3. **`displays correct sidebar structure`** - Checks for proper widget hierarchy (Container, Column, SafeArea)
4. **`renders with proper width constraint`** - Ensures sidebar has correct 280px max width

### **🔘 Callback Functionality Tests**
5. **`calls onCreateBase callback`** - Tests that Create Base button triggers the callback
6. **`calls onJoinBase callback`** - Tests that Join Base button triggers the callback
7. **`handles null callbacks gracefully`** - Ensures no crashes when callbacks are null
8. **`handles callback interactions properly`** - Comprehensive test of all callback interactions

### **📊 Data Display Tests**
9. **`displays bases list when bases are available`** - Tests rendering of multiple bases with proper duplication handling
   - Base names appear correctly (Test Base 1 once, Test Base 2 twice)
   - Descriptions appear correctly (A test base once, Another test base twice)
   - Current Base section appears
   - Handles auto-selection of most recent base

### **🔄 State Management Tests**
10. **`shows loading state initially`** - Verifies MoonSpinner appears during data loading
11. **`shows empty state when no bases available`** - Tests empty state message display
12. **`handles error state gracefully`** - Tests error handling with retry functionality

## Technical Implementation

### **Mocktail Integration**
- **`MockBasesRepository`** and **`MockProfileRepository`** for dependency injection
- **Provider overrides** to inject mocks into Riverpod providers
- **Flexible mock behaviors** (delays, errors, empty responses)

### **Asynchronous Testing Patterns**
- **Session controller timing** (600ms wait for initialization)
- **Loading state simulation** (100ms delayed responses)
- **Proper pump sequences** (`pump` + `pumpAndSettle`)

### **Test Data Setup**
```dart
testBases = [
  Base(
    id: 'base1',
    name: 'Test Base 1',
    ownerUserId: 'user1',
    description: 'A test base',
    createdAt: DateTime(2024, 1, 1),
    updatedAt: DateTime(2024, 1, 1),
  ),
  Base(
    id: 'base2',
    name: 'Test Base 2',
    ownerUserId: 'user1',
    description: 'Another test base',
    createdAt: DateTime(2024, 1, 2), // More recent
    updatedAt: DateTime(2024, 1, 2),
  ),
];
```

## Key Testing Patterns

### **Provider Override Pattern**
```dart
Widget createTestWidget({...}) {
  return ProviderScope(
    overrides: [
      basesRepositoryProvider.overrideWith(
        (ref) => mockBasesRepository,
      ),
      profileRepositoryProvider.overrideWith(
        (ref) => mockProfileRepository,
      ),
    ],
    child: MaterialApp(...),
  );
}
```

### **Asynchronous Test Flow**
```dart
// 1. Render widget
await tester.pumpWidget(createTestWidget());

// 2. Wait for session controller initialization
await tester.pump(const Duration(milliseconds: 600));

// 3. Wait for all async operations to complete
await tester.pumpAndSettle();

// 4. Assert expectations
expect(find.text('My Bases'), findsOneWidget);
```

### **Loading State Simulation**
```dart
// Override mock to simulate loading delay
when(() => mockBasesRepository.listMyBases(any())).thenAnswer(
  (_) => Future.delayed(const Duration(milliseconds: 100), () => testBases),
);

// Check loading state before delayed response
expect(find.byType(MoonSpinner), findsOneWidget);

// Wait for response to complete
await tester.pumpAndSettle();
```

## Behavior-Driven Testing Approach

### **Realistic Test Scenarios**
- **Multiple bases** with different creation dates
- **Auto-selection logic** (most recent base appears in Current Base section)
- **Duplicate content handling** (base appears in both list and Current Base section)

### **State Coverage**
- **Loading states** during data fetching
- **Empty states** when no bases available
- **Error states** with retry functionality
- **Success states** with proper data display

### **Interaction Testing**
- **Button taps** trigger appropriate callbacks
- **Null callback handling** prevents crashes
- **Multiple callback interactions** work correctly

## Performance & Reliability Benefits

### **Mocktail Advantages**
- **Faster execution** compared to manual mocks
- **Type-safe mocking** with compile-time verification
- **Simplified setup** and maintenance

### **Timing Control**
- **Eliminated timing issues** with SessionController
- **Deterministic test results** with controlled async behavior
- **Consistent test execution** across different environments

### **Comprehensive Coverage**
- **All widget states** (loading, empty, error, success)
- **All user interactions** (button taps, callback handling)
- **Edge cases** (null callbacks, network errors)

## Test Execution

### **Running Individual Tests**
```bash
# Run specific test
flutter test test/widgets/base_sidebar_test.dart -p vm --plain-name "displays bases list when bases are available"

# Run all BaseSidebar tests
flutter test test/widgets/base_sidebar_test.dart
```

### **Test Output Example**
```
00:04 +9: BaseSidebar Widget Tests displays bases list when bases are available
00:04 +10: BaseSidebar Widget Tests shows empty state when no bases available
00:05 +11: BaseSidebar Widget Tests handles error state gracefully
00:05 +11: All tests passed!
```

## Maintenance & Extensions

### **Adding New Tests**
1. **Follow existing patterns** for consistency
2. **Use descriptive test names** that explain the behavior being tested
3. **Mock dependencies appropriately** for the test scenario
4. **Test actual behavior** rather than implementation details

### **Updating Test Data**
- **Modify `setUp()`** to change test data
- **Update mock behaviors** for different scenarios
- **Ensure test data reflects** real-world usage patterns

### **Debugging Test Failures**
- **Check mock setup** and provider overrides
- **Verify timing** with pump sequences
- **Review test expectations** against actual widget behavior

## Conclusion

The BaseSidebar test suite provides **robust, reliable testing** with **12 comprehensive test cases** covering all major functionality. The suite demonstrates best practices for:

- **Mocktail integration** for improved performance
- **Behavior-driven testing** for reliable results
- **Comprehensive state coverage** for all widget scenarios
- **Maintainable test structure** for future development

This test suite ensures the BaseSidebar widget functions correctly across all states and user interactions, providing confidence in the component's reliability and behavior.
