import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moonbase_skeleton/services/bases_repository.dart';
import 'package:moonbase_skeleton/services/invites_repository.dart';
import 'package:moonbase_skeleton/services/chat_repository.dart';
import 'package:moonbase_skeleton/models/enums.dart';
import 'package:moonbase_skeleton/models/base.dart';
import 'package:moonbase_skeleton/models/base_member.dart';
import 'package:moonbase_skeleton/models/chat_message.dart';
import 'package:moonbase_skeleton/models/invite.dart';

/// Comprehensive functional test for MoonBase core functionality
/// Tests all major features: bases, invites, chat, and real-time streaming
void main() {
  group('MoonBase Functional Tests', () {
    late SpBasesRepository basesRepo;
    late SpInvitesRepository invitesRepo;
    late SpChatRepository chatRepo;
    late SharedPreferences prefs;
    
    const testUserId = 'user_123';
    const testUserId2 = 'user_456';
    const testBaseName = 'Test Base';
    const testBaseDescription = 'A test base for functional testing';

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

    setUp(() async {
      // Initialize repositories for each test
      // Use the same SharedPreferences instance that was set up with mock data
      basesRepo = SpBasesRepository();
      invitesRepo = SpInvitesRepository();
      chatRepo = SpChatRepository();
      
      // Clear any previous test data
      await prefs.clear();
      
      // Re-setup mock current user for each test
      await prefs.setString('mb.currentUser', 'testuser');
      await prefs.setString('mb.users', jsonEncode({
        'testuser': jsonEncode({
          'userId': testUserId,
          'nickname': 'testuser',
        })
      }));
    });

    tearDown(() async {
      // Cleanup after each test
      chatRepo.dispose();
    });

    test('Complete base lifecycle with chat', () async {
      // Test 1: Create a base
      final base = await basesRepo.createBase(
        name: testBaseName,
        description: testBaseDescription,
        userId: testUserId,
      );
      
      expect(base, isA<Base>());
      expect(base.name, equals(testBaseName));
      expect(base.description, equals(testBaseDescription));
      expect(base.ownerUserId, equals(testUserId));
      expect(base.memberIds, contains(testUserId));

      // Test 2: List bases
      final bases = await basesRepo.listMyBases(testUserId);
      expect(bases, isNotEmpty);
      expect(bases.first.id, equals(base.id));
      expect(bases.first.name, equals(testBaseName));

      // Test 3: Create an invite
      final invite = await invitesRepo.createInvite(
        baseId: base.id,
        userId: testUserId,
        maxUses: 3,
      );
      
      expect(invite, isA<BaseInvite>());
      expect(invite.baseId, equals(base.id));
      expect(invite.maxUses, equals(3));
      expect(invite.code, isNotEmpty);

      // Test 4: Add member directly (bypassing invite redemption)
      final member = await basesRepo.addMember(
        baseId: base.id,
        userId: testUserId2,
        role: BaseRole.member,
      );
      
      expect(member, isA<BaseMember>());
      expect(member.userId, equals(testUserId2));
      expect(member.baseId, equals(base.id));
      expect(member.role, equals(BaseRole.member));

      // Test 5: Send messages
      final message1 = await chatRepo.sendMessage(
        baseId: base.id,
        authorUserId: testUserId,
        type: MessageType.text,
        text: 'Hello from the owner!',
      );
      
      expect(message1, isA<ChatMessage>());
      expect(message1.text, equals('Hello from the owner!'));
      expect(message1.authorUserId, equals(testUserId));
      expect(message1.baseId, equals(base.id));

      final message2 = await chatRepo.sendMessage(
        baseId: base.id,
        authorUserId: testUserId2,
        type: MessageType.text,
        text: 'Hello from the new member!',
      );
      
      expect(message2, isA<ChatMessage>());
      expect(message2.text, equals('Hello from the new member!'));
      expect(message2.authorUserId, equals(testUserId2));

      // Test 6: Get messages
      final messages = await chatRepo.getMessages(baseId: base.id);
      expect(messages.length, greaterThanOrEqualTo(2));
      expect(messages.any((msg) => msg.text == 'Hello from the owner!'), isTrue);
      expect(messages.any((msg) => msg.text == 'Hello from the new member!'), isTrue);

      // Test 7: Edit message
      final editedMessage = await chatRepo.editMessage(
        messageId: message1.id,
        newText: 'Hello from the owner! (edited)',
      );
      
      expect(editedMessage.text, equals('Hello from the owner! (edited)'));
      expect(editedMessage.id, equals(message1.id));

      // Test 8: List members
      final members = await basesRepo.listMembers(base.id);
      expect(members.length, equals(2));
      expect(members.any((m) => m.userId == testUserId && m.role == BaseRole.owner), isTrue);
      expect(members.any((m) => m.userId == testUserId2 && m.role == BaseRole.member), isTrue);

      // Test 9: Check ownership
      final isOwner1 = await basesRepo.isOwner(baseId: base.id, userId: testUserId);
      final isOwner2 = await basesRepo.isOwner(baseId: base.id, userId: testUserId2);
      
      expect(isOwner1, isTrue);
      expect(isOwner2, isFalse);
    });

    test('Real-time message streaming', () async {
      // Create a base for streaming test
      final base = await basesRepo.createBase(
        name: 'Streaming Test Base',
        description: 'Testing real-time streaming',
        userId: testUserId,
      );

      // Set up stream listener
      final stream = chatRepo.streamMessages(baseId: base.id);
      final receivedMessages = <ChatMessage>[];
      
      final subscription = stream.listen((messageList) {
        receivedMessages.addAll(messageList);
      });

      // Send a message to trigger stream
      final testMessage = await chatRepo.sendMessage(
        baseId: base.id,
        authorUserId: testUserId,
        type: MessageType.text,
        text: 'Stream test message!',
      );

      // Wait for stream to process
      await Future.delayed(const Duration(milliseconds: 200));
      
      expect(receivedMessages, isNotEmpty);
      expect(receivedMessages.any((msg) => msg.text == 'Stream test message!'), isTrue);

      subscription.cancel();
    });

    test('Invite creation and validation', () async {
      // Create a base
      final base = await basesRepo.createBase(
        name: 'Invite Test Base',
        description: 'Testing invite system',
        userId: testUserId,
      );

      // Create invite with multiple uses
      final invite = await invitesRepo.createInvite(
        baseId: base.id,
        userId: testUserId,
        maxUses: 2,
      );

      expect(invite.baseId, equals(base.id));
      expect(invite.maxUses, equals(2));
      expect(invite.usedCount, equals(0));
      expect(invite.isDepleted, isFalse);

      // Test invite retrieval by code
      final retrievedInvite = await invitesRepo.getByCode(invite.code);
      expect(retrievedInvite, isNotNull);
      expect(retrievedInvite!.id, equals(invite.id));
      expect(retrievedInvite.code, equals(invite.code));
    });

    test('Message editing and persistence', () async {
      // Create a base
      final base = await basesRepo.createBase(
        name: 'Message Test Base',
        description: 'Testing message functionality',
        userId: testUserId,
      );

      // Send initial message
      final originalMessage = await chatRepo.sendMessage(
        baseId: base.id,
        authorUserId: testUserId,
        type: MessageType.text,
        text: 'Original message',
      );

      // Edit the message
      final editedMessage = await chatRepo.editMessage(
        messageId: originalMessage.id,
        newText: 'Edited message',
      );

      expect(editedMessage.text, equals('Edited message'));
      expect(editedMessage.id, equals(originalMessage.id));

      // Verify persistence by getting messages again
      final messages = await chatRepo.getMessages(baseId: base.id);
      final persistedMessage = messages.firstWhere((msg) => msg.id == originalMessage.id);
      expect(persistedMessage.text, equals('Edited message'));
    });

    test('Base management operations', () async {
      // Create multiple bases
      final base1 = await basesRepo.createBase(
        name: 'Base 1',
        description: 'First test base',
        userId: testUserId,
      );
      
      final base2 = await basesRepo.createBase(
        name: 'Base 2',
        description: 'Second test base',
        userId: testUserId,
      );

      // List all bases for user
      final userBases = await basesRepo.listMyBases(testUserId);
      expect(userBases.length, greaterThanOrEqualTo(2));
      expect(userBases.any((b) => b.id == base1.id), isTrue);
      expect(userBases.any((b) => b.id == base2.id), isTrue);

      // Get specific base
      final retrievedBase = await basesRepo.getBase(base1.id);
      expect(retrievedBase, isNotNull);
      expect(retrievedBase!.name, equals('Base 1'));

      // Test member management
      await basesRepo.addMember(
        baseId: base1.id,
        userId: testUserId2,
        role: BaseRole.member,
      );

      final members = await basesRepo.listMembers(base1.id);
      expect(members.length, equals(2));
      expect(members.any((m) => m.userId == testUserId2), isTrue);
    });
  });
}
