import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/core/sync_status.dart';
import 'package:moonbase_skeleton/core/validators.dart';
import 'package:moonbase_skeleton/features/chat/domain/entities/message.dart';
import 'package:moonbase_skeleton/features/chat/domain/repositories/chat_repository.dart';
import 'package:moonbase_skeleton/features/chat/domain/usecases/send_message.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_constraints.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_type.dart';

class _MockChatRepo extends Mock implements ChatRepository {}

MediaRef _mediaRef([int i = 0]) => MediaRef(
      id: MediaId('media_$i'),
      type: MediaType.image,
      storageKey: 'b1/media_$i.jpg',
    );

Message _stubMessage(String content, List<MediaRef> media) => Message(
      id: const MessageId('m1'),
      baseId: const BaseId('b1'),
      userId: const UserId('u1'),
      content: content,
      createdAt: DateTime(2026, 6, 22),
      media: media,
      syncStatus: SyncStatus.synced,
    );

void main() {
  group('SendMessage', () {
    late _MockChatRepo repo;
    late SendMessage useCase;

    setUpAll(() {
      registerFallbackValue(<MediaRef>[]);
      registerFallbackValue(const BaseId('_'));
      registerFallbackValue(const UserId('_'));
    });

    setUp(() {
      repo = _MockChatRepo();
      useCase = SendMessage(repo);
    });

    SendMessageParams params({
      String content = 'hello',
      List<MediaRef> media = const [],
    }) =>
        SendMessageParams(
          baseId: const BaseId('b1'),
          userId: const UserId('u1'),
          content: content,
          media: media,
        );

    test('forwards trimmed text-only payload to the repo and returns Right',
        () async {
      when(() => repo.sendMessage(
            baseId: any(named: 'baseId'),
            userId: any(named: 'userId'),
            content: any(named: 'content'),
            media: any(named: 'media'),
          )).thenAnswer(
        (_) async => Right(_stubMessage('hello', const [])),
      );

      final result = await useCase(params(content: '  hello  '));

      expect(result, isA<Right<Failure, Message>>());
      verify(() => repo.sendMessage(
            baseId: const BaseId('b1'),
            userId: const UserId('u1'),
            content: 'hello',
            media: const [],
          )).called(1);
    });

    test('forwards media-only payload (empty text) to the repo', () async {
      final media = [_mediaRef()];
      when(() => repo.sendMessage(
            baseId: any(named: 'baseId'),
            userId: any(named: 'userId'),
            content: any(named: 'content'),
            media: any(named: 'media'),
          )).thenAnswer((_) async => Right(_stubMessage('', media)));

      final result = await useCase(params(content: '   ', media: media));

      expect(result, isA<Right<Failure, Message>>());
      verify(() => repo.sendMessage(
            baseId: any(named: 'baseId'),
            userId: any(named: 'userId'),
            content: '',
            media: media,
          )).called(1);
    });

    test('rejects when both text and media are empty (no repo call)',
        () async {
      final result = await useCase(params(content: '   ', media: const []));

      expect(result, isA<Left<Failure, Message>>());
      final failure = (result as Left<Failure, Message>).value;
      expect(failure, isA<ValidationFailure>());
      verifyZeroInteractions(repo);
    });

    test('rejects content longer than kMessageMaxLen', () async {
      final result = await useCase(
        params(content: 'x' * (kMessageMaxLen + 1)),
      );

      expect(result, isA<Left<Failure, Message>>());
      final failure = (result as Left<Failure, Message>).value;
      expect(failure, isA<ValidationFailure>());
      expect(failure.message, contains('$kMessageMaxLen'));
      verifyZeroInteractions(repo);
    });

    test('rejects when media.length exceeds maxMediaPerMessageDefault',
        () async {
      final media = List.generate(
        MediaConstraints.maxMediaPerMessageDefault + 1,
        _mediaRef,
      );

      final result = await useCase(params(media: media));

      expect(result, isA<Left<Failure, Message>>());
      final failure = (result as Left<Failure, Message>).value;
      expect(failure, isA<ValidationFailure>());
      expect(
        failure.message,
        contains('${MediaConstraints.maxMediaPerMessageDefault}'),
      );
      verifyZeroInteractions(repo);
    });

    test('forwards full payload (text + media at the cap) on success',
        () async {
      final media = List.generate(
        MediaConstraints.maxMediaPerMessageDefault,
        _mediaRef,
      );
      when(() => repo.sendMessage(
            baseId: any(named: 'baseId'),
            userId: any(named: 'userId'),
            content: any(named: 'content'),
            media: any(named: 'media'),
          )).thenAnswer((_) async => Right(_stubMessage('hi', media)));

      final result = await useCase(params(content: 'hi', media: media));

      expect(result, isA<Right<Failure, Message>>());
      verify(() => repo.sendMessage(
            baseId: const BaseId('b1'),
            userId: const UserId('u1'),
            content: 'hi',
            media: media,
          )).called(1);
    });
  });
}
