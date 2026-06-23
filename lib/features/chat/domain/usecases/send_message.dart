import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/core/usecase.dart';
import 'package:moonbase_skeleton/core/validators.dart';
import 'package:moonbase_skeleton/features/chat/domain/entities/message.dart';
import 'package:moonbase_skeleton/features/chat/domain/repositories/chat_repository.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_constraints.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';

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
/// failures already come back as `Left(Failure)` via `guard(...)`.
class SendMessage implements UseCase<Message, SendMessageParams> {
  const SendMessage(this.repo);

  final ChatRepository repo;

  @override
  Future<Either<Failure, Message>> call(SendMessageParams p) {
    final content = p.content.trim();
    final media = p.media;

    if (!isValidMessageInput(text: content, mediaCount: media.length)) {
      if (content.length > kMessageMaxLen) {
        return Future.value(const Left(ValidationFailure(
          'Message can\'t exceed $kMessageMaxLen characters.',
        )));
      }
      return Future.value(const Left(ValidationFailure(
        'Message must contain text or at least one attachment.',
      )));
    }

    if (media.length > MediaConstraints.maxMediaPerMessageDefault) {
      return Future.value(const Left(ValidationFailure(
        'Too many attachments (max ${MediaConstraints.maxMediaPerMessageDefault}).',
      )));
    }

    return repo.sendMessage(
      baseId: p.baseId,
      userId: p.userId,
      content: content,
      media: media,
    );
  }
}
