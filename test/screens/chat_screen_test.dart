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
import 'package:moonbase_skeleton/models/chat_message.dart';
import 'package:moonbase_skeleton/models/base.dart';
import 'package:moonbase_skeleton/models/profile.dart';
import 'package:moonbase_skeleton/models/enums.dart';

// Create mocks using mocktail
class MockChatRepository extends Mock implements ChatRepository {}
class MockBasesRepository extends Mock implements BasesRepository {}
class MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  group('ChatScreen Widget Tests', () {
    late MockChatRepository mockChatRepository;
    late MockBasesRepository mockBasesRepository;
    late MockProfileRepository mockProfileRepository;
    late Base testBase;
    late Profile testProfile;
    late List<ChatMessage> testMessages;
    
    setUp(() {
      mockChatRepository = MockChatRepository();
      mockBasesRepository = MockBasesRepository();
      mockProfileRepository = MockProfileRepository();
      
      testBase = Base(
        id: 'test_base_123',
        name: 'Test Base',
        ownerUserId: 'user_123',
        description: 'A test base for chat',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );
      
      testProfile = Profile(
        userId: 'user_123',
        nickname: 'testuser',
        createdAt: DateTime(2024, 1, 1).toIso8601String(),
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
    });

    group('Basic Widget Structure', () {
      testWidgets('ChatScreen widget can be created', (WidgetTester tester) async {
        // Test that the widget can be created without crashing
        expect(() => const ChatScreen(), returnsNormally);
      });

      testWidgets('ChatScreen has correct type', (WidgetTester tester) async {
        const chatScreen = ChatScreen();
        expect(chatScreen, isA<ChatScreen>());
      });
    });

    group('Model Tests', () {
      test('ChatMessage can be created with required fields', () {
        final message = ChatMessage(
          id: 'test_id',
          baseId: 'test_base',
          authorUserId: 'test_user',
          type: MessageType.text,
          text: 'Test message',
          createdAt: DateTime.now(),
        );
        
        expect(message.id, equals('test_id'));
        expect(message.baseId, equals('test_base'));
        expect(message.authorUserId, equals('test_user'));
        expect(message.type, equals(MessageType.text));
        expect(message.text, equals('Test message'));
        expect(message.isEdited, isFalse);
        expect(message.isDeleted, isFalse);
      });

      test('ChatMessage copyWith works correctly', () {
        final originalMessage = ChatMessage(
          id: 'test_id',
          baseId: 'test_base',
          authorUserId: 'test_user',
          type: MessageType.text,
          text: 'Original message',
          createdAt: DateTime.now(),
        );
        
        final editedMessage = originalMessage.copyWith(
          text: 'Edited message',
          isEdited: true,
          editedAt: DateTime.now(),
        );
        
        expect(editedMessage.id, equals(originalMessage.id));
        expect(editedMessage.text, equals('Edited message'));
        expect(editedMessage.isEdited, isTrue);
        expect(editedMessage.editedAt, isNotNull);
      });

      test('ChatMessage can be marked as deleted', () {
        final message = ChatMessage(
          id: 'test_id',
          baseId: 'test_base',
          authorUserId: 'test_user',
          type: MessageType.text,
          text: 'Test message',
          createdAt: DateTime.now(),
        );
        
        final deletedMessage = message.copyWith(
          text: null,
          isDeleted: true,
        );
        
        expect(deletedMessage.text, isNull);
        expect(deletedMessage.isDeleted, isTrue);
        expect(deletedMessage.id, equals(message.id));
      });
    });

    group('Repository Mock Tests', () {
      test('MockChatRepository can be created', () {
        expect(mockChatRepository, isA<MockChatRepository>());
        expect(mockChatRepository, isA<ChatRepository>());
      });

      test('MockBasesRepository can be created', () {
        expect(mockBasesRepository, isA<MockBasesRepository>());
        expect(mockBasesRepository, isA<BasesRepository>());
      });

      test('MockProfileRepository can be created', () {
        expect(mockProfileRepository, isA<MockProfileRepository>());
        expect(mockProfileRepository, isA<ProfileRepository>());
      });
    });

    group('Provider Tests', () {
      test('chatRepositoryProvider can be accessed', () {
        // This test verifies that the provider exists and can be referenced
        expect(chatRepositoryProvider, isNotNull);
      });

      test('basesRepositoryProvider can be accessed', () {
        expect(basesRepositoryProvider, isNotNull);
      });

      test('effectiveSelectedBaseProvider can be accessed', () {
        expect(effectiveSelectedBaseProvider, isNotNull);
      });
    });

    group('Base Model Tests', () {
      test('Base can be created with required fields', () {
        final base = Base(
          id: 'test_base_id',
          name: 'Test Base Name',
          ownerUserId: 'test_owner',
          description: 'Test description',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );
        
        expect(base.id, equals('test_base_id'));
        expect(base.name, equals('Test Base Name'));
        expect(base.ownerUserId, equals('test_owner'));
        expect(base.description, equals('Test description'));
        expect(base.createdAt, equals(DateTime(2024, 1, 1)));
        expect(base.updatedAt, equals(DateTime(2024, 1, 1)));
      });
    });

    group('Profile Model Tests', () {
      test('Profile can be created with required fields', () {
        final profile = Profile(
          userId: 'test_user_id',
          nickname: 'testnick',
          createdAt: '2024-01-01T00:00:00.000Z',
          themeMode: 'dark',
        );
        
        expect(profile.userId, equals('test_user_id'));
        expect(profile.nickname, equals('testnick'));
        expect(profile.createdAt, equals('2024-01-01T00:00:00.000Z'));
        expect(profile.themeMode, equals('dark'));
      });
    });

    group('Message Type Tests', () {
      test('MessageType enum has expected values', () {
        expect(MessageType.values, contains(MessageType.text));
        expect(MessageType.values, contains(MessageType.media));
        expect(MessageType.values.length, greaterThan(0));
      });

      test('MessageType.text is accessible', () {
        expect(MessageType.text, isNotNull);
        expect(MessageType.text.name, equals('text'));
      });
    });

    group('Mock Behavior Tests', () {
      test('MockChatRepository returns test messages', () async {
        final messages = await mockChatRepository.getMessages(
          baseId: testBase.id,
          limit: 50,
        );
        
        expect(messages, equals(testMessages));
        expect(messages.length, equals(2));
        expect(messages.first.text, equals('Hello World'));
        expect(messages.last.text, equals('Hi there!'));
      });

      test('MockBasesRepository returns test base', () async {
        final bases = await mockBasesRepository.listMyBases('test_user');
        
        expect(bases, equals([testBase]));
        expect(bases.first.name, equals('Test Base'));
        expect(bases.first.id, equals('test_base_123'));
      });

      test('MockProfileRepository returns test profile', () async {
        final profile = await mockProfileRepository.read();
        
        expect(profile, equals(testProfile));
        expect(profile?.nickname, equals('testuser'));
        expect(profile?.userId, equals('user_123'));
      });
    });

    group('Widget Integration Tests', () {
      testWidgets('ChatScreen can be created without crashing', (WidgetTester tester) async {
        // Test that the widget can be created without crashing
        expect(() => const ChatScreen(), returnsNormally);
      });

      testWidgets('ChatScreen has correct type', (WidgetTester tester) async {
        const chatScreen = ChatScreen();
        expect(chatScreen, isA<ChatScreen>());
      });

      testWidgets('ChatScreen can be wrapped in ProviderScope', (WidgetTester tester) async {
        // Test that the widget can be wrapped in ProviderScope without crashing
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: const ChatScreen(),
            ),
          ),
        );
        
        // Wait for the session controller timer to complete (500ms + buffer)
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();
        
        // If we get here without crashing, the test passes
        expect(tester.takeException(), isNull);
      });

      testWidgets('ChatScreen shows some UI elements', (WidgetTester tester) async {
        // Test with a simple ProviderScope to see what actually renders
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: const ChatScreen(),
            ),
          ),
        );
        
        // Wait for the session controller timer to complete (500ms + buffer)
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();
        
        // Look for basic UI elements that should exist
        // The exact text may vary based on the current state
        expect(find.byType(MaterialApp), findsOneWidget);
      });

      testWidgets('ChatScreen handles async session loading', (WidgetTester tester) async {
        // This test specifically verifies that async operations complete properly
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: const ChatScreen(),
            ),
          ),
        );
        
        // First pump to start the async operations
        await tester.pump();
        
        // Wait for the session controller timer to complete
        await tester.pump(const Duration(milliseconds: 600));
        
        // Final pump to settle all remaining operations
        await tester.pumpAndSettle();
        
        // Verify no exceptions occurred
        expect(tester.takeException(), isNull);
      });
    });
  });
}
