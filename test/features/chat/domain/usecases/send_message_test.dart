import 'dart:typed_data';

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
import 'package:moonbase_skeleton/features/media/domain/repositories/media_storage.dart';

class _MockChatRepo extends Mock implements ChatRepository {}

class _MockMediaStorage extends Mock implements MediaStorage {}

MediaRef _mediaRef([int i = 0]) => MediaRef(
      id: MediaId('media_$i'),
      type: MediaType.image,
      storageKey: 'b1/media_$i.jpg',
    );

/// Cloud path the mock cloud storage "returns" for a staged local key.
String _cloudPathFor(String localKey) =>
    'bases/b1/media/${localKey.split('/').last}';

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
    late _MockMediaStorage staging;
    late _MockMediaStorage cloud;
    late SendMessage useCase;

    setUpAll(() {
      registerFallbackValue(<MediaRef>[]);
      registerFallbackValue(const BaseId('_'));
      registerFallbackValue(const UserId('_'));
      registerFallbackValue(<int>[]);
    });

    setUp(() {
      repo = _MockChatRepo();
      staging = _MockMediaStorage();
      cloud = _MockMediaStorage();
      useCase = SendMessage(
        repo,
        stagingStorage: staging,
        cloudStorage: cloud,
        // Never touch the real filesystem in unit tests.
        readStagedBytes: (uri) async => Uint8List.fromList([1, 2, 3]),
      );
    });

    /// Happy-path stubs: staging resolves to a file URI, cloud upload
    /// succeeds and returns the canonical cloud path for the key.
    void stubUploadsSucceed() {
      when(() => staging.resolveUri(any()))
          .thenAnswer((inv) async => 'file:///staged/${inv.positionalArguments[0]}');
      when(() => cloud.putBytes(
            key: any(named: 'key'),
            bytes: any(named: 'bytes'),
            mimeType: any(named: 'mimeType'),
          )).thenAnswer(
        (inv) async => _cloudPathFor(inv.namedArguments[#key] as String),
      );
    }

    void stubRepoSuccess(String content, List<MediaRef> media) {
      when(() => repo.sendMessage(
            baseId: any(named: 'baseId'),
            userId: any(named: 'userId'),
            content: any(named: 'content'),
            media: any(named: 'media'),
          )).thenAnswer((_) async => Right(_stubMessage(content, media)));
    }

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
      stubRepoSuccess('hello', const []);

      final result = await useCase(params(content: '  hello  '));

      expect(result, isA<Right<Failure, Message>>());
      verify(() => repo.sendMessage(
            baseId: const BaseId('b1'),
            userId: const UserId('u1'),
            content: 'hello',
            media: const [],
          )).called(1);
      // Text-only sends never touch media storage.
      verifyZeroInteractions(staging);
      verifyZeroInteractions(cloud);
    });

    test('forwards media-only payload (empty text) to the repo', () async {
      final media = [_mediaRef()];
      stubUploadsSucceed();
      stubRepoSuccess('', media);

      final result = await useCase(params(content: '   ', media: media));

      expect(result, isA<Right<Failure, Message>>());
      verify(() => repo.sendMessage(
            baseId: any(named: 'baseId'),
            userId: any(named: 'userId'),
            content: '',
            media: any(named: 'media'),
          )).called(1);
    });

    test('rejects when both text and media are empty (no repo call)',
        () async {
      final result = await useCase(params(content: '   ', media: const []));

      expect(result, isA<Left<Failure, Message>>());
      final failure = (result as Left<Failure, Message>).value;
      expect(failure, isA<ValidationFailure>());
      verifyZeroInteractions(repo);
      verifyZeroInteractions(cloud);
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
      // Validation runs before any upload — no orphan on a rejected payload.
      verifyZeroInteractions(cloud);
    });

    test(
        'uploads every attachment then creates the message once with '
        'cloud storage keys (upload-then-create)', () async {
      final media = [_mediaRef(0), _mediaRef(1)];
      stubUploadsSucceed();
      stubRepoSuccess('hi', media);

      final result = await useCase(params(content: 'hi', media: media));

      expect(result, isA<Right<Failure, Message>>());

      // Each staged attachment was uploaded exactly once, in order. (That
      // the create only happens after uploads is proven by the
      // all-or-nothing test below: a failed upload → repo never called.)
      verifyInOrder([
        () => cloud.putBytes(
              key: 'b1/media_0.jpg',
              bytes: any(named: 'bytes'),
              mimeType: any(named: 'mimeType'),
            ),
        () => cloud.putBytes(
              key: 'b1/media_1.jpg',
              bytes: any(named: 'bytes'),
              mimeType: any(named: 'mimeType'),
            ),
      ]);

      // The message doc gets the rewritten cloud paths, not the local keys.
      final sent = verify(() => repo.sendMessage(
            baseId: const BaseId('b1'),
            userId: const UserId('u1'),
            content: 'hi',
            media: captureAny(named: 'media'),
          )).captured.single as List<MediaRef>;
      expect(
        sent.map((m) => m.storageKey).toList(),
        ['bases/b1/media/media_0.jpg', 'bases/b1/media/media_1.jpg'],
      );
    });

    test(
        'all-or-nothing: a failed upload aborts the send — no message doc, '
        'failure surfaced as Left', () async {
      final media = [_mediaRef(0), _mediaRef(1)];
      when(() => staging.resolveUri(any()))
          .thenAnswer((inv) async => 'file:///staged/x');
      // First upload succeeds; second throws a typed Failure (as the pass-1
      // FirebaseMediaStorage does).
      when(() => cloud.putBytes(
            key: 'b1/media_0.jpg',
            bytes: any(named: 'bytes'),
            mimeType: any(named: 'mimeType'),
          )).thenAnswer((_) async => _cloudPathFor('b1/media_0.jpg'));
      when(() => cloud.putBytes(
            key: 'b1/media_1.jpg',
            bytes: any(named: 'bytes'),
            mimeType: any(named: 'mimeType'),
          )).thenThrow(const NetworkFailure('upload failed'));

      final result = await useCase(params(content: 'hi', media: media));

      expect(result, isA<Left<Failure, Message>>());
      final failure = (result as Left<Failure, Message>).value;
      expect(failure, isA<NetworkFailure>());
      expect(failure.message, 'upload failed');
      // The partial success (media_0, now an orphan in Storage) must NOT
      // produce a message doc.
      verifyNever(() => repo.sendMessage(
            baseId: any(named: 'baseId'),
            userId: any(named: 'userId'),
            content: any(named: 'content'),
            media: any(named: 'media'),
          ));
    });

    test(
        'retry after partial upload starts clean: same local keys re-uploaded, '
        'exactly one message with only fresh cloud paths', () async {
      // Same MediaRef instances the UI would retain across failure → retry
      // (ChatScreen keeps _stagedMedia; use case must not mutate them).
      final media = [_mediaRef(0), _mediaRef(1)];
      when(() => staging.resolveUri(any()))
          .thenAnswer((inv) async => 'file:///staged/${inv.positionalArguments[0]}');

      var media1Attempts = 0;
      when(() => cloud.putBytes(
            key: 'b1/media_0.jpg',
            bytes: any(named: 'bytes'),
            mimeType: any(named: 'mimeType'),
          )).thenAnswer((_) async => _cloudPathFor('b1/media_0.jpg'));
      when(() => cloud.putBytes(
            key: 'b1/media_1.jpg',
            bytes: any(named: 'bytes'),
            mimeType: any(named: 'mimeType'),
          )).thenAnswer((_) async {
        media1Attempts++;
        if (media1Attempts == 1) {
          throw const NetworkFailure('upload failed');
        }
        return _cloudPathFor('b1/media_1.jpg');
      });

      final first = await useCase(params(content: 'hi', media: media));
      expect(first, isA<Left<Failure, Message>>());
      verifyNever(() => repo.sendMessage(
            baseId: any(named: 'baseId'),
            userId: any(named: 'userId'),
            content: any(named: 'content'),
            media: any(named: 'media'),
          ));

      // Staged refs must still hold local keys — not cloud paths from the
      // aborted attempt — so retry is a full re-upload, not a resume.
      expect(media.map((m) => m.storageKey).toList(), [
        'b1/media_0.jpg',
        'b1/media_1.jpg',
      ]);

      stubRepoSuccess('hi', media);
      final second = await useCase(params(content: 'hi', media: media));
      expect(second, isA<Right<Failure, Message>>());

      // putBytes was always called with local keys (never cloud paths).
      final putKeys = verify(() => cloud.putBytes(
            key: captureAny(named: 'key'),
            bytes: any(named: 'bytes'),
            mimeType: any(named: 'mimeType'),
          )).captured.cast<String>();
      expect(putKeys, [
        'b1/media_0.jpg', // attempt 1
        'b1/media_1.jpg', // attempt 1 (fails)
        'b1/media_0.jpg', // retry
        'b1/media_1.jpg', // retry
      ]);
      expect(putKeys, everyElement(isNot(startsWith('bases/'))));

      // Exactly one message create; mediaPaths are only fresh cloud paths.
      final sent = verify(() => repo.sendMessage(
            baseId: const BaseId('b1'),
            userId: const UserId('u1'),
            content: 'hi',
            media: captureAny(named: 'media'),
          )).captured.single as List<MediaRef>;
      expect(
        sent.map((m) => m.storageKey).toList(),
        ['bases/b1/media/media_0.jpg', 'bases/b1/media/media_1.jpg'],
      );
    });

    test('raw (non-Failure) upload throw is guarded into Left, never thrown',
        () async {
      final media = [_mediaRef()];
      when(() => staging.resolveUri(any()))
          .thenAnswer((_) async => 'file:///staged/x');
      when(() => cloud.putBytes(
            key: any(named: 'key'),
            bytes: any(named: 'bytes'),
            mimeType: any(named: 'mimeType'),
          )).thenThrow(Exception('plugin blew up'));

      final result = await useCase(params(media: media));

      expect(result, isA<Left<Failure, Message>>());
      verifyNever(() => repo.sendMessage(
            baseId: any(named: 'baseId'),
            userId: any(named: 'userId'),
            content: any(named: 'content'),
            media: any(named: 'media'),
          ));
    });

    test('staging resolve failure aborts before any upload', () async {
      final media = [_mediaRef()];
      when(() => staging.resolveUri(any()))
          .thenThrow(const CacheFailure('staged file missing'));

      final result = await useCase(params(media: media));

      expect(result, isA<Left<Failure, Message>>());
      final failure = (result as Left<Failure, Message>).value;
      expect(failure, isA<CacheFailure>());
      verifyZeroInteractions(cloud);
      verifyZeroInteractions(repo);
    });

    test('forwards full payload (text + media at the cap) on success',
        () async {
      final media = List.generate(
        MediaConstraints.maxMediaPerMessageDefault,
        _mediaRef,
      );
      stubUploadsSucceed();
      stubRepoSuccess('hi', media);

      final result = await useCase(params(content: 'hi', media: media));

      expect(result, isA<Right<Failure, Message>>());
      final sent = verify(() => repo.sendMessage(
            baseId: const BaseId('b1'),
            userId: const UserId('u1'),
            content: 'hi',
            media: captureAny(named: 'media'),
          )).captured.single as List<MediaRef>;
      expect(sent, hasLength(MediaConstraints.maxMediaPerMessageDefault));
      expect(
        sent.map((m) => m.storageKey),
        everyElement(startsWith('bases/b1/media/')),
      );
    });
  });
}
