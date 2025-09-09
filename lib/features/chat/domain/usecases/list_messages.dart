import '../../../../core/either.dart';
import '../../../../core/failure.dart';
import '../../../../core/usecase.dart';
import '../entities/message.dart';
import '../repositories/chat_repository.dart';

class ListMessagesParams {
  final String baseId;
  final DateTime? before;
  final int limit;
  const ListMessagesParams({required this.baseId, this.before, this.limit = 50});
}

class ListMessages implements UseCase<List<Message>, ListMessagesParams> {
  final ChatRepository repo;
  const ListMessages(this.repo);

  @override
  Future<Either<Failure, List<Message>>> call(ListMessagesParams p) =>
      repo.listMessages(baseId: p.baseId, before: p.before, limit: p.limit);
}
