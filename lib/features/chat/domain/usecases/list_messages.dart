import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/usecase.dart';
import 'package:moonbase_skeleton/features/chat/domain/entities/message.dart';
import 'package:moonbase_skeleton/features/chat/domain/repositories/chat_repository.dart';

class ListMessagesParams {
  const ListMessagesParams({required this.baseId, this.before, this.limit = 50});

  final String baseId;
  final DateTime? before;
  final int limit;
}

class ListMessages implements UseCase<List<Message>, ListMessagesParams> {
  const ListMessages(this.repo);

  final ChatRepository repo;

  @override
  Future<Either<Failure, List<Message>>> call(ListMessagesParams p) =>
      repo.listMessages(baseId: p.baseId, before: p.before, limit: p.limit);
}
