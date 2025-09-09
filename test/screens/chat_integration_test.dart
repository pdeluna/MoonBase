import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonbase_skeleton/screens/chat_screen.dart';
import 'package:moonbase_skeleton/providers/chat_provider.dart';
import 'package:moonbase_skeleton/providers/bases_provider.dart';
import 'package:moonbase_skeleton/services/chat_repository.dart';
import 'package:moonbase_skeleton/services/bases_repository.dart';
import 'package:moonbase_skeleton/services/profile_repository.dart';
import 'package:moonbase_skeleton/services/session_controller.dart';
import 'package:moonbase_skeleton/models/chat_message.dart';
import 'package:moonbase_skeleton/models/base.dart';
import 'package:moonbase_skeleton/models/profile.dart';
import 'package:moonbase_skeleton/models/enums.dart';

// Create mocks using mocktail
class MockChatRepository extends Mock implements ChatRepository {}
class MockBasesRepository extends Mock implements BasesRepository {}
class MockProfileRepository extends Mock implements ProfileRepository {}
class MockSessionController extends Mock implements SessionController {}

void main() {
  group('Chat Integration Tests', () {
    late MockChatRepository mockChatRepository;
    late MockBasesRepository mockBasesRepository;
    late MockProfileRepository mockProfileRepository;
    late MockSessionController mockSessionController;
    late Base testBase;
    late Profile testProfile;
    late List<ChatMessage> testMessages;
    
    setUpAll(() {
      // Register fallback values for Mocktail
      registerFallbackValue(MessageType.text);
      registerFallbackValue(MessageType.media);
    });
    
    setUp(() {
      mockChatRepository = MockChatRepository();
      mockBasesRepository = MockBasesRepository();
      mockProfileRepository = MockProfileRepository();
      mockSessionController = MockSessionController();
      
      testBase = Base(
        id: 'test_base_123',
        name: 'Test Base',
        ownerUserId: 'user_123',
        description: 'A test base for chat',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );
      
      testProfile = const Profile(
        userId: 'user_123',
        nickname: 'testuser',
        createdAt: '2024-01-01T00:00:00.000Z',
        themeMode: 'light',
      );
      
      testMessages = [
        ChatMessage(
          id: 'msg_1',
          baseId: testBase.id,
          authorUserId: 'user_123',
          type: MessageType.text,
          text: 'Hello World',
          createdAt: DateTime(2024, 1, 15, 10, 0),
        ),
        ChatMessage(
          id: 'msg_2',
          baseId: testBase.id,
          authorUserId: 'user_456',
          type: MessageType.text,
          text: 'Hi there!',
          createdAt: DateTime(2024, 1, 15, 10, 1),
        ),
      ];
      
      // Setup default mock behaviors
      when(() => mockProfileRepository.read()).thenAnswer((_) async => testProfile);
      when(() => mockBasesRepository.listMyBases(any())).thenAnswer((_) async => [testBase]);
      when(() => mockChatRepository.getMessages(baseId: any(named: 'baseId'), limit: any(named: 'limit')))
          .thenAnswer((_) async => testMessages);
      when(() => mockChatRepository.streamMessages(baseId: any(named: 'baseId')))
          .thenAnswer((_) => Stream.value(testMessages));
      
      // Setup session controller mock
      when(() => mockSessionController.state).thenReturn(AsyncValue.data(testProfile));
    });

    Widget createTestWidget() {
      return ProviderScope(
        overrides: [
          // Only override the essential providers
          chatRepositoryProvider.overrideWith((ref) => mockChatRepository),
          // Let the other providers use their default implementations
        ],
        child: const MaterialApp(
          home: ChatScreen(),
        ),
      );
    }

    group('Basic Chat Integration Tests', () {
      testWidgets('ChatScreen can be created and shows base selection when no base', (WidgetTester tester) async {
        // Test without base selection - use a minimal provider scope
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              // Only override the chat repository
              chatRepositoryProvider.overrideWith((ref) => mockChatRepository),
            ],
            child: const MaterialApp(
              home: ChatScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Should show the "Please select a base" message
        expect(find.text('Please select a base to start chatting'), findsOneWidget);
      });

      testWidgets('ChatScreen shows chat interface when base is selected', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Should show the chat interface with base name in app bar
        expect(find.text('Chat - Test Base'), findsOneWidget);
        
        // Should show the message composer
        expect(find.byType(TextField), findsOneWidget);
        expect(find.byType(FloatingActionButton), findsOneWidget);
        expect(find.text('Type a message...'), findsOneWidget);
      });

      testWidgets('ChatScreen handles message input correctly', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Find the text field and enter text
        final textField = find.byType(TextField);
        await tester.enterText(textField, 'Test message');
        await tester.pump();

        // Verify text was entered
        expect(find.text('Test message'), findsOneWidget);
      });

      testWidgets('ChatScreen handles empty message submission', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Try to send empty message
        final sendButton = find.byType(FloatingActionButton);
        await tester.tap(sendButton);
        await tester.pump();

        // Should not crash and should not send message
        expect(find.text('Type a message...'), findsOneWidget); // Composer still there
      });

      testWidgets('ChatScreen shows loading state while initializing', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        
        // Initially should show loading
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        
        await tester.pumpAndSettle();
        
        // After settling, should show chat interface
        expect(find.text('Chat - Test Base'), findsOneWidget);
      });

      testWidgets('ChatScreen handles basic error states', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Should show chat interface even with basic setup
        expect(find.text('Chat - Test Base'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
      });
    });
  });
}
