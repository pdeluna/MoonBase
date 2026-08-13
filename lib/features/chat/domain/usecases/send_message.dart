import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';

import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/error_mapper.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/core/usecase.dart';
import 'package:moonbase_skeleton/core/validators.dart';
import 'package:moonbase_skeleton/features/chat/domain/entities/message.dart';
import 'package:moonbase_skeleton/features/chat/domain/repositories/chat_repository.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_constraints.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';
import 'package:moonbase_skeleton/features/media/domain/repositories/media_storage.dart';

/// Reads the bytes of a staged attachment given the URI resolved by the
/// staging [MediaStorage]. Injectable so tests never touch the filesystem;
/// the default reads a `file://` URI via `dart:io`.
///
/// **iOS unverified:** default `File.fromUri` path is proven on Android only;
/// iOS staging/file-path behavior differs — verify on iOS build day (see
/// FIRESTORE_SCHEMA.md Task 3 notes alongside HEIC).
typedef StagedBytesReader = Future<Uint8List> Function(String uri);

Future<Uint8List> _readFileUriBytes(String uri) =>
    File.fromUri(Uri.parse(uri)).readAsBytes();

class SendMessageParams {
  const SendMessageParams({
    required this.baseId,
    required this.userId,
    required this.content,
    this.media = const [],
  });

  final BaseId baseId;
  final UserId userId;
  final String content;

  /// Zero or more media attachments. Capped per message by
  /// `MediaConstraints.maxMediaPerMessageDefault` (default 4). The use case
  /// also rejects the call when this is empty AND [content] is blank.
  final List<MediaRef> media;
}

/// Validates a chat-message payload then forwards to the repository.
///
/// Phase 3 (Slice A) validation rules — kept in this single file so the UI
/// and the use case cannot disagree about what "a valid message" is:
///
/// 1. **Text-or-media rule.** At least one of (non-empty trimmed text) or
///    (non-empty media list) must be present. Both empty → `Left(ValidationFailure)`.
/// 2. **Text length cap.** Trimmed text length must not exceed
///    `kMessageMaxLen`.
/// 3. **Media count cap.** `media.length` must not exceed
///    `MediaConstraints.maxMediaPerMessageDefault` (default 4).
///
/// All three checks return `Left(ValidationFailure)` with a user-facing
/// message. There is intentionally no `try`/`catch` here — repository
/// failures already come back as `Left(Failure)` via `guard(...)`, and every
/// staging-read / cloud-upload step below runs inside `guard(...)` too.
///
/// ## Week 5 task 3 pass 2 — upload-then-create
///
/// When [SendMessageParams.media] is non-empty, each staged attachment is
/// read from [stagingStorage] and uploaded via [cloudStorage] (the pass-1
/// `FirebaseMediaStorage`, which compresses to JPEG and throws typed
/// `Failure`s). The message doc is created **once, after all uploads
/// resolve**, with the returned cloud paths as the attachments' storage keys
/// — never create-then-patch (Firestore rules deny message updates).
///
/// **All-or-nothing:** if any upload fails, no message is created and the
/// first failure is returned as `Left`. Attachments uploaded before the
/// failure remain **orphaned** in Storage — accepted MVP tradeoff, logged
/// below; client cleanup is impossible (Storage ADR denies client deletes)
/// and deferred to the Admin-cleanup trigger row.
///
/// **Guard obligation honored:** `putBytes` throws typed failures; every
/// staging-read + upload runs inside `guard(...)`, so failures surface as
/// `Left(Failure)`, never a raw throw.
class SendMessage implements UseCase<Message, SendMessageParams> {
  SendMessage(
    this.repo, {
    required this.stagingStorage,
    required this.cloudStorage,
    StagedBytesReader? readStagedBytes,
  }) : _readStagedBytes = readStagedBytes ?? _readFileUriBytes;

  final ChatRepository repo;

  /// Where the picker persisted the staged bytes (local files).
  final MediaStorage stagingStorage;

  /// Cloud upload target (compress + upload; throws typed `Failure`s).
  final MediaStorage cloudStorage;

  final StagedBytesReader _readStagedBytes;

  @override
  Future<Either<Failure, Message>> call(SendMessageParams p) async {
    final content = p.content.trim();
    final media = p.media;

    if (!isValidMessageInput(text: content, mediaCount: media.length)) {
      if (content.length > kMessageMaxLen) {
        return const Left(ValidationFailure(
          'Message can\'t exceed $kMessageMaxLen characters.',
        ));
      }
      return const Left(ValidationFailure(
        'Message must contain text or at least one attachment.',
      ));
    }

    if (media.length > MediaConstraints.maxMediaPerMessageDefault) {
      return const Left(ValidationFailure(
        'Too many attachments (max ${MediaConstraints.maxMediaPerMessageDefault}).',
      ));
    }

    var mediaToSend = media;
    if (media.isNotEmpty) {
      final uploadResult = await _uploadAll(media);
      final failure = uploadResult.match<Failure?>((f) => f, (uploaded) {
        mediaToSend = uploaded;
        return null;
      });
      if (failure != null) return Left(failure);
    }

    return repo.sendMessage(
      baseId: p.baseId,
      userId: p.userId,
      content: content,
      media: mediaToSend,
    );
  }

  /// Uploads every staged attachment sequentially; aborts on the first
  /// failure (all-or-nothing). On success returns the attachments with
  /// [MediaRef.storageKey] rewritten to the canonical cloud path returned
  /// by [MediaStorage.putBytes].
  Future<Either<Failure, List<MediaRef>>> _uploadAll(
    List<MediaRef> media,
  ) async {
    final uploaded = <MediaRef>[];
    for (final m in media) {
      final result = await guard(() async {
        final uri = await stagingStorage.resolveUri(m.storageKey);
        final bytes = await _readStagedBytes(uri);
        final cloudPath = await cloudStorage.putBytes(
          key: m.storageKey,
          bytes: bytes,
          mimeType: m.mimeType ?? 'image/jpeg',
        );
        return m.copyWith(storageKey: cloudPath);
      });

      final failure = result.match<Failure?>((f) => f, (ref) {
        uploaded.add(ref);
        return null;
      });
      if (failure != null) {
        // Accepted MVP tradeoff: already-uploaded objects are now orphans in
        // Storage. Client delete is denied by the Storage ADR — do not
        // attempt cleanup here; deferred to Admin-side cleanup.
        developer.log(
          'Send aborted after ${uploaded.length}/${media.length} uploads '
          '(${failure.message}). Orphaned objects: '
          '${uploaded.map((u) => u.storageKey).join(', ')}',
          name: 'SendMessage',
        );
        return Left(failure);
      }
    }
    return Right(List.unmodifiable(uploaded));
  }
}
