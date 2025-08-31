import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moonbase_skeleton/services/bases_repository.dart';
import 'package:moonbase_skeleton/services/invites_repository.dart';
import 'package:moonbase_skeleton/services/chat_repository.dart';
import 'package:moonbase_skeleton/models/base.dart';
import 'package:moonbase_skeleton/models/base_member.dart';
import 'package:moonbase_skeleton/models/invite.dart';
import 'package:moonbase_skeleton/models/chat_message.dart';
import 'package:moonbase_skeleton/models/enums.dart';

void main() {
  group('Integration Tests', () {
    late SpBasesRepository basesRepository;
    late SpInvitesRepository invitesRepository;
    late SpChatRepository chatRepository;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      basesRepository = SpBasesRepository();
      invitesRepository = SpInvitesRepository();
      chatRepository = SpChatRepository();
    });

    tearDown(() async {
      await prefs.clear();
      chatRepository.dispose();
    });

    test('Complete flow: Create base, invite user, chat', () async {
      // Setup mock current user with proper JSON structure
      await prefs.setString('mb.currentUser', 'alice');
      await prefs.setString('mb.users', '{"alice": "{\\"userId\\":\\"user_alice\\",\\"nickname\\":\\"alice\\"}", "bob": "{\\"userId\\":\\"user_bob\\",\\"nickname\\":\\"bob\\"}"}');

      // 1. Alice creates a base
      final base = await basesRepository.createBase(
        name: 'Alice\'s Base',
        description: 'A private space for friends',
        userId: 'user_alice',
      );

      expect(base.name, equals('Alice\'s Base'));
      expect(base.ownerUserId, equals('user_alice'));

      // Verify Alice can see her base
      final aliceBases = await basesRepository.listMyBases('user_alice');
      expect(aliceBases.length, equals(1));
      expect(aliceBases.first.id, equals(base.id));

      // 2. Alice creates an invite
      final invite = await invitesRepository.createInvite(
        baseId: base.id,
        userId: 'user_alice',
        maxUses: 3,
      );

      expect(invite.baseId, equals(base.id));
      expect(invite.createdByUserId, equals('user_alice'));
      expect(invite.maxUses, equals(3));
      expect(invite.usedCount, equals(0));

      // 3. Bob redeems the invite
      final member = await invitesRepository.redeemInvite(
        code: invite.code,
        userId: 'user_bob',
      );

      expect(member.userId, equals('user_bob'));
      expect(member.baseId, equals(base.id));
      expect(member.role, equals(BaseRole.member));

      // Verify Bob can now see the base
      final bobBases = await basesRepository.listMyBases('user_bob');
      expect(bobBases.length, equals(1));
      expect(bobBases.first.id, equals(base.id));

      // Verify invite usage count increased
      final updatedInvite = await invitesRepository.getByCode(invite.code);
      expect(updatedInvite!.usedCount, equals(1));

      // 4. Alice and Bob can chat in the base
      final aliceMessage = await chatRepository.sendMessage(
        baseId: base.id,
        authorUserId: 'user_alice',
        type: MessageType.text,
        text: 'Welcome to my base, Bob!',
      );

      final bobMessage = await chatRepository.sendMessage(
        baseId: base.id,
        authorUserId: 'user_bob',
        type: MessageType.text,
        text: 'Thanks for the invite, Alice!',
      );

      // Verify messages are saved
      final messages = await chatRepository.getMessages(baseId: base.id);
      expect(messages.length, equals(2));
      expect(messages.map((m) => m.text), containsAll([
        'Welcome to my base, Bob!',
        'Thanks for the invite, Alice!',
      ]));

      // 5. Test real-time streaming
      final stream = chatRepository.streamMessages(baseId: base.id);
      final streamMessages = <List<ChatMessage>>[];
      final subscription = stream.listen((messageList) {
        streamMessages.add(messageList);
      });

      // Send another message
      await chatRepository.sendMessage(
        baseId: base.id,
        authorUserId: 'user_alice',
        type: MessageType.text,
        text: 'How are you doing?',
      );

      // Wait for stream to update
      await Future.delayed(const Duration(milliseconds: 100));

      expect(streamMessages.length, greaterThan(0));
      final latestMessages = streamMessages.last;
      expect(latestMessages.length, equals(3));
      expect(latestMessages.any((m) => m.text == 'How are you doing?'), isTrue);

      subscription.cancel();

      // 6. Test message editing
      final editedMessage = await chatRepository.editMessage(
        messageId: aliceMessage.id,
        newText: 'Welcome to my base, Bob! (edited)',
      );

      expect(editedMessage.text, equals('Welcome to my base, Bob! (edited)'));
      expect(editedMessage.isEdited, isTrue);

      // 7. Test message deletion
      await chatRepository.deleteMessage(bobMessage.id);

      final messagesAfterDeletion = await chatRepository.getMessages(baseId: base.id);
      final deletedMessage = messagesAfterDeletion.firstWhere((m) => m.id == bobMessage.id);
      expect(deletedMessage.isDeleted, isTrue);
      expect(deletedMessage.text, isNull);

      // 8. Test base members
      final members = await basesRepository.listMembers(base.id);
      expect(members.length, equals(2));
      expect(members.any((m) => m.userId == 'user_alice' && m.role == BaseRole.owner), isTrue);
      expect(members.any((m) => m.userId == 'user_bob' && m.role == BaseRole.member), isTrue);

      // 9. Test owner validation
      final aliceIsOwner = await basesRepository.isOwner(baseId: base.id, userId: 'user_alice');
      final bobIsOwner = await basesRepository.isOwner(baseId: base.id, userId: 'user_bob');

      expect(aliceIsOwner, isTrue);
      expect(bobIsOwner, isFalse);
    });

    test('Multiple users can join via invite', () async {
      // Setup mock users
      await prefs.setString('mb.currentUser', 'owner');
      await prefs.setString('mb.users', '{"owner": "{\\"userId\\":\\"user_owner\\",\\"nickname\\":\\"owner\\"}", "user1": "{\\"userId\\":\\"user_1\\",\\"nickname\\":\\"user1\\"}", "user2": "{\\"userId\\":\\"user_2\\",\\"nickname\\":\\"user_2\\"}"}');

      // Create base
      final base = await basesRepository.createBase(name: 'Multi-User Base', userId: 'user_owner');

      // Create invite
      final invite = await invitesRepository.createInvite(
        baseId: base.id,
        userId: 'user_owner',
        maxUses: 5,
      );

      // Multiple users join
      final member1 = await invitesRepository.redeemInvite(
        code: invite.code,
        userId: 'user_1',
      );

      final member2 = await invitesRepository.redeemInvite(
        code: invite.code,
        userId: 'user_2',
      );

      // Verify all users can see the base
      final ownerBases = await basesRepository.listMyBases('user_owner');
      final user1Bases = await basesRepository.listMyBases('user_1');
      final user2Bases = await basesRepository.listMyBases('user_2');

      expect(ownerBases.length, equals(1));
      expect(user1Bases.length, equals(1));
      expect(user2Bases.length, equals(1));

      // Verify invite usage count
      final updatedInvite = await invitesRepository.getByCode(invite.code);
      expect(updatedInvite!.usedCount, equals(2));

      // Verify all members
      final members = await basesRepository.listMembers(base.id);
      expect(members.length, equals(3));
      expect(members.any((m) => m.userId == 'user_owner' && m.role == BaseRole.owner), isTrue);
      expect(members.any((m) => m.userId == 'user_1' && m.role == BaseRole.member), isTrue);
      expect(members.any((m) => m.userId == 'user_2' && m.role == BaseRole.member), isTrue);
    });

    test('Invite validation and error handling', () async {
      await prefs.setString('mb.currentUser', 'owner');
      await prefs.setString('mb.users', '{"owner": "{\\"userId\\":\\"user_owner\\",\\"nickname\\":\\"owner\\"}", "user1": "{\\"userId\\":\\"user_1\\",\\"nickname\\":\\"user1\\"}"}');

      final base = await basesRepository.createBase(name: 'Test Base', userId: 'user_owner');

      // Test invalid invite code
      expect(
        () => invitesRepository.redeemInvite(
          code: 'INVALID',
          userId: 'user_1',
        ),
        throwsA(isA<Exception>()),
      );

      // Test expired invite
      final expiredInvite = await invitesRepository.createInvite(
        baseId: base.id,
        userId: 'user_owner',
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
      );

      expect(
        () => invitesRepository.redeemInvite(
          code: expiredInvite.code,
          userId: 'user_1',
        ),
        throwsA(isA<Exception>()),
      );

      // Test depleted invite
      final limitedInvite = await invitesRepository.createInvite(
        baseId: base.id,
        userId: 'user_owner',
        maxUses: 1,
      );

      // First redemption should work
      await invitesRepository.redeemInvite(
        code: limitedInvite.code,
        userId: 'user_1',
      );

      // Second redemption should fail
      expect(
        () => invitesRepository.redeemInvite(
          code: limitedInvite.code,
          userId: 'user_2',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
