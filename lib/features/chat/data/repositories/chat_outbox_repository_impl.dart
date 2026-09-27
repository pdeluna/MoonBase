import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/error_mapper.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/chat/data/datasources/chat_outbox_local_data_source.dart';
import 'package:moonbase_skeleton/features/chat/data/models/message_model.dart';
import 'package:moonbase_skeleton/features/chat/domain/entities/message.dart';
import 'package:moonbase_skeleton/features/chat/domain/repositories/chat_outbox.dart';

/// `ChatOutbox` over a local data source. Local-only I/O, so plain `guard`
/// (no timeout) — there is no network wait to bound here.
class ChatOutboxRepositoryImpl implements ChatOutbox {
  ChatOutboxRepositoryImpl({required this.local});

  final ChatOutboxLocalDataSource local;

  @override
  Future<Either<Failure, List<Message>>> loadAll() => guard(() async {
        final rows = await local.loadAll();
        return rows.map((m) => m.toEntity()).toList(growable: false);
      });

  @override
  Future<Either<Failure, void>> upsert(Message message) => guardVoid(
        () => local.upsert(
          MessageModel(
            id: message.id.value,
            baseId: message.baseId.value,
            userId: message.userId.value,
            content: message.content,
            createdAt: message.createdAt,
            media: message.media,
            syncStatus: message.syncStatus,
          ),
        ),
      );

  @override
  Future<Either<Failure, void>> remove(MessageId id) =>
      guardVoid(() => local.remove(id.value));
}
