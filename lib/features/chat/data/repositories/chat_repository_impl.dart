import '../../../../core/either.dart';
import '../../../../core/failure.dart';
import '../../domain/entities/message.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/chat_local_data_source.dart';
import '../datasources/chat_remote_data_source.dart';

class ChatRepositoryImpl implements ChatRepository {
  final ChatLocalDataSource local;
  final ChatRemoteDataSource? remote;

  ChatRepositoryImpl({required this.local, this.remote});

  @override
  Future<Either<Failure, Message>> sendMessage({
    required String baseId,
    required String userId,
    required String content,
  }) async {
    try {
      final m = await local.sendMessage(baseId: baseId, userId: userId, content: content);
      return Right(m.toEntity());
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Stream<List<Message>> streamMessages(String baseId) =>
      local.streamMessages(baseId).map((ms) => ms.map((m) => m.toEntity()).toList());

  @override
  Future<Either<Failure, List<Message>>> listMessages({
    required String baseId,
    DateTime? before,
    int limit = 50,
  }) async {
    try {
      final list = await local.listMessages(baseId: baseId, before: before, limit: limit);
      return Right(list.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }
}
