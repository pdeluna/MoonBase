import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/chat/domain/entities/message.dart';
import 'package:moonbase_skeleton/features/chat/domain/repositories/chat_repository.dart';
import 'package:moonbase_skeleton/features/chat/data/datasources/chat_local_data_source.dart';
import 'package:moonbase_skeleton/features/chat/data/datasources/chat_remote_data_source.dart';
import 'package:moonbase_skeleton/core/error_mapper.dart';

class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl({required this.local, this.remote});

  final ChatLocalDataSource local;
  final ChatRemoteDataSource? remote;

  @override
  Future<Either<Failure, Message>> sendMessage({required BaseId baseId, required UserId userId, required String content}) =>
    guard(() async {
      final m = await local.sendMessage(baseId: baseId.value, userId: userId.value, content: content);
      return m.toEntity();
    });

  @override
  Future<Either<Failure, List<Message>>> listMessages({required BaseId baseId, DateTime? before, int limit = 50}) =>
    guard(() async {
      final ms = await local.listMessages(baseId: baseId.value, before: before, limit: limit);
      return ms.map((m) => m.toEntity()).toList();
    });

  @override
  Stream<List<Message>> streamMessages(BaseId baseId) =>
      local.streamMessages(baseId.value).map((ms) => ms.map((m) => m.toEntity()).toList());

}
