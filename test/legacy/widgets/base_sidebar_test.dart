import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonbase_skeleton/legacy/widgets/base_sidebar.dart';
import 'package:moonbase_skeleton/legacy/providers/bases_provider.dart';
import 'package:moonbase_skeleton/legacy/services/session_controller.dart';
import 'package:moonbase_skeleton/legacy/services/bases_repository.dart';
import 'package:moonbase_skeleton/legacy/services/profile_repository.dart';
import 'package:moonbase_skeleton/legacy/models/base.dart';
import 'package:moonbase_skeleton/legacy/models/profile.dart';
import 'package:moonbase_skeleton/legacy/widgets/moon_spinner.dart';

// Create mocks using mocktail
class MockBasesRepository extends Mock implements BasesRepository {}
class MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  group('BaseSidebar Widget Tests', () {
    late MockBasesRepository mockBasesRepository;
    late MockProfileRepository mockProfileRepository;
    late List<Base> testBases;
    late Profile testProfile;
    
    setUp(() {
      mockBasesRepository = MockBasesRepository();
      mockProfileRepository = MockProfileRepository();
      
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
          createdAt: DateTime(2024, 1, 2),
          updatedAt: DateTime(2024, 1, 2),
        ),
      ];
      
        testProfile = Profile(
        userId: 'user1',
        nickname: 'testuser',
        createdAt: DateTime(2024, 1, 1).toIso8601String(),
        themeMode: 'light',
      );
      
      // Setup default mock behaviors
      when(() => mockProfileRepository.read()).thenAnswer((_) async => testProfile);
      when(() => mockBasesRepository.listMyBases(any())).thenAnswer((_) async => testBases);
    });

    Widget createTestWidget({
      VoidCallback? onBaseSelected,
      VoidCallback? onCreateBase,
      VoidCallback? onJoinBase,
    }) {
      return ProviderScope(
        overrides: [
          // Override the bases repository provider
          basesRepositoryProvider.overrideWith(
            (ref) => mockBasesRepository,
          ),
          // Override the profile repository provider
          profileRepositoryProvider.overrideWith(
            (ref) => mockProfileRepository,
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: BaseSidebar(
              onBaseSelected: onBaseSelected,
              onCreateBase: onCreateBase,
              onJoinBase: onJoinBase,
            ),
          ),
        ),
      );
    }

    testWidgets('renders header correctly', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      
      // Wait for the session controller to initialize
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      
      expect(find.text('My Bases'), findsOneWidget);
      expect(find.text('Switch between your bases'), findsOneWidget);
    });

    testWidgets('renders action buttons', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      
      expect(find.text('Create Base'), findsOneWidget);
      expect(find.text('Join Base'), findsOneWidget);
    });

    testWidgets('calls onCreateBase callback', (WidgetTester tester) async {
      bool createBaseCalled = false;
      
      await tester.pumpWidget(createTestWidget(
        onCreateBase: () => createBaseCalled = true,
      ));
      
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      
      await tester.tap(find.text('Create Base'));
      await tester.pumpAndSettle();
      
      expect(createBaseCalled, isTrue);
    });

    testWidgets('calls onJoinBase callback', (WidgetTester tester) async {
      bool joinBaseCalled = false;
      
      await tester.pumpWidget(createTestWidget(
        onJoinBase: () => joinBaseCalled = true,
      ));
      
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      
      await tester.tap(find.text('Join Base'));
      await tester.pumpAndSettle();
      
      expect(joinBaseCalled, isTrue);
    });

    testWidgets('handles null callbacks gracefully', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      
      // Should not crash when callbacks are null
      await tester.tap(find.text('Create Base'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Join Base'));
      await tester.pumpAndSettle();
      
      // No errors should occur
      expect(tester.takeException(), isNull);
    });

    testWidgets('displays correct sidebar structure', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      
      // Check that the sidebar has the expected structure
      expect(find.byType(Container), findsWidgets);
      expect(find.byType(Column), findsWidgets);
      expect(find.byType(SafeArea), findsWidgets);
    });

    testWidgets('renders with proper width constraint', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      
      final sidebar = tester.widget<Container>(find.byType(Container).first);
      expect(sidebar.constraints?.maxWidth, equals(280));
    });

    testWidgets('shows loading state initially', (WidgetTester tester) async {
      // Override the mock to delay the response to simulate loading
      when(() => mockBasesRepository.listMyBases(any())).thenAnswer(
        (_) => Future.delayed(const Duration(milliseconds: 100), () => testBases),
      );
      
      await tester.pumpWidget(createTestWidget());
      
      // Wait for the session controller to initialize first
      await tester.pump(const Duration(milliseconds: 600));
      
      // Now check for loading state (before the delayed response)
      expect(find.byType(MoonSpinner), findsOneWidget);
      
      // Wait for the delayed response to complete
      await tester.pumpAndSettle();
      
      // Should now show the actual content
      expect(find.text('My Bases'), findsOneWidget);
    });

    testWidgets('handles callback interactions properly', (WidgetTester tester) async {
      bool createBaseCalled = false;
      bool joinBaseCalled = false;
      
      await tester.pumpWidget(createTestWidget(
        onCreateBase: () => createBaseCalled = true,
        onJoinBase: () => joinBaseCalled = true,
      ));
      
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      
      // Test all callbacks
      await tester.tap(find.text('Create Base'));
      await tester.pumpAndSettle();
      expect(createBaseCalled, isTrue);
      
      await tester.tap(find.text('Join Base'));
      await tester.pumpAndSettle();
      expect(joinBaseCalled, isTrue);
    });

    testWidgets('displays bases list when bases are available', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      
      // Test that both bases are displayed in the list
      expect(find.text('Test Base 1'), findsOneWidget);
      // Test Base 2 appears twice: once in list, once in Current Base section
      expect(find.text('Test Base 2'), findsNWidgets(2));
      
      // Test that descriptions are displayed
      expect(find.text('A test base'), findsOneWidget);
      // "Another test base" appears twice: once in list, once in Current Base section
      expect(find.text('Another test base'), findsNWidgets(2));
      
      // Test that the Current Base section appears
      expect(find.text('Current Base'), findsOneWidget);
      
      // Test that one base appears in both the list and Current Base section
      // (Test Base 2 gets auto-selected as most recent, so it appears twice)
      expect(find.text('Test Base 2'), findsNWidgets(2));
    });

    testWidgets('shows empty state when no bases available', (WidgetTester tester) async {
      // Override the mock to return empty list
      when(() => mockBasesRepository.listMyBases(any())).thenAnswer((_) async => []);
      
      await tester.pumpWidget(createTestWidget());
      
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      
      // Should show empty state
      expect(find.text('No bases yet'), findsOneWidget);
      expect(find.text('Create your first base to start sharing with your circle'), findsOneWidget);
    });

    testWidgets('handles error state gracefully', (WidgetTester tester) async {
      // Override the mock to throw an error
      when(() => mockBasesRepository.listMyBases(any())).thenThrow(Exception('Network error'));
      
      await tester.pumpWidget(createTestWidget());
      
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      
      // Should show error state
      expect(find.text('Error loading bases'), findsOneWidget);
      expect(find.text('Exception: Network error'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
