import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/core/sync_status.dart';
import 'package:moonbase_skeleton/features/chat/domain/entities/chat_feed.dart';
import 'package:moonbase_skeleton/features/chat/domain/entities/message.dart';
import 'package:moonbase_skeleton/features/chat/domain/repositories/chat_outbox.dart';
import 'package:moonbase_skeleton/features/chat/domain/usecases/send_message.dart';
import 'package:moonbase_skeleton/features/chat/domain/usecases/stream_messages.dart';
import 'package:moonbase_skeleton/features/chat/presentation/providers/chat_providers.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';

/// A message the user has sent that the backend has not acknowledged.
///
/// [message] carries the status on `Message.syncStatus` (`uploading` while
/// the send use case runs, `failed` after a `Left`). [failure] is the last
/// `Failure` for a failed entry — presentation-only; the persisted outbox
/// row stores just the status.
class PendingSend {
  const PendingSend({required this.message, this.failure});

  final Message message;
  final Failure? failure;

  String get id => message.id.value;
  bool get isFailed => message.syncStatus == SyncStatus.failed;

  PendingSend copyWith({Message? message, Failure? failure}) =>
      PendingSend(message: message ?? this.message, failure: failure);
}

/// One-shot signal that a send just failed, for the screen's alert. [seq]
/// makes consecutive failures of the same message distinguishable so a
/// `ref.listen` fires for each.
class SendFailureEvent {
  const SendFailureEvent({
    required this.seq,
    required this.messageId,
    required this.failure,
  });

  final int seq;
  final MessageId messageId;
  final Failure failure;

  @override
  bool operator ==(Object other) =>
      other is SendFailureEvent && other.seq == seq;

  @override
  int get hashCode => seq.hashCode;
}

class ChatState {
  const ChatState({
    this.feed = const AsyncValue<ChatFeed>.loading(),
    this.pending = const <PendingSend>[],
    this.lastSendFailure,
  });

  final AsyncValue<ChatFeed> feed;

  /// Unacknowledged sends across every base, oldest first. The VM filters
  /// by the selected base and dedupes against the live feed by id.
  final List<PendingSend> pending;

  final SendFailureEvent? lastSendFailure;

  ChatState copyWith({
    AsyncValue<ChatFeed>? feed,
    List<PendingSend>? pending,
    SendFailureEvent? lastSendFailure,
  }) =>
      ChatState(
        feed: feed ?? this.feed,
        pending: pending ?? this.pending,
        lastSendFailure: lastSendFailure ?? this.lastSendFailure,
      );
}

/// Chat feed + pending-send outbox orchestration.
///
/// Send flow (bug B-c): `send` mints a client id, appends a `uploading`
/// [PendingSend], persists it to the [ChatOutbox], then runs `SendMessage`.
/// `Right` → the entry is settled (removed from state and outbox). `Left` →
/// the entry flips to `failed`, [ChatState.lastSendFailure] fires, and the
/// outbox row is updated so the failure survives termination. `retry`
/// re-runs the same id with the same media; `discard` drops it.
///
/// Reconciliation: whenever the live feed delivers a document whose id is
/// pending, the entry is settled — the backend (or Firestore's own
/// persistence queue) now owns delivery, and a second `set()` of the same
/// id would be an update the rules deny.
///
/// Replay: `load(baseId, userId: …)` restores outbox rows for that base and
/// signed-in user and re-dispatches them sequentially. Rows authored by
/// another account on the device are left untouched.
///
/// No write timeout is added here — the unbounded Firestore write is the
/// parked R3 trigger #12; the pending spinner is the honest UI for it.
class ChatController extends StateNotifier<ChatState> {
  ChatController(
    this._sendMessage,
    this._streamMessages, {
    required ChatOutbox outbox,
    Uuid? uuid,
    DateTime Function()? now,
  })  : _outbox = outbox,
        _uuid = uuid ?? const Uuid(),
        _now = now ?? (() => DateTime.now().toUtc()),
        super(const ChatState());

  final SendMessage _sendMessage;
  final StreamMessages _streamMessages;
  final ChatOutbox _outbox;
  final Uuid _uuid;
  final DateTime Function() _now;

  StreamSubscription<ChatFeed>? _sub;
  final Set<String> _inFlight = <String>{};
  int _failureSeq = 0;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  /// Sorts messages newest first so ListView(reverse: true) shows newest at bottom.
  static List<Message> _newestFirst(List<Message> list) {
    final copy = List<Message>.from(list);
    copy.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return copy;
  }

  /// Subscribe to the message stream. First paint is the first ChatFeed
  /// emission — do not mint a freshness value from listMessages.
  /// Pagination is not wired; listMessagesUseCaseProvider stays for that.
  ///
  /// When [userId] is given, outbox rows for (`baseId`, `userId`) are
  /// restored into [ChatState.pending] and replayed.
  Future<void> load(String baseId, {String? userId}) async {
    _sub?.cancel();
    state = state.copyWith(feed: const AsyncValue<ChatFeed>.loading());

    developer.log('ChatController: Starting stream for base $baseId');
    _sub = _streamMessages(baseId.bid).listen(
      (feed) {
        if (!mounted) return;
        developer.log(
          'ChatController: Received ${feed.messages.length} messages from stream',
        );
        state = state.copyWith(
          feed: AsyncValue.data(
            ChatFeed(
              messages: _newestFirst(feed.messages),
              freshness: feed.freshness,
            ),
          ),
        );
        _reconcileWithFeed(feed.messages);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!mounted) return;
        state = state.copyWith(feed: AsyncValue.error(error, stackTrace));
      },
    );

    if (userId != null) {
      await restoreOutbox(baseId, userId);
    }
  }

  /// Loads persisted outbox rows for [baseId] authored by [userId] that are
  /// not already tracked, marks them `uploading`, and replays them in order.
  /// Replay runs in the background; the returned future completes once the
  /// rows are visible in state.
  Future<void> restoreOutbox(String baseId, String userId) async {
    final res = await _outbox.loadAll();
    final rows = res.match(
      (failure) {
        developer.log(
          'ChatController: outbox load failed - ${failure.message}',
        );
        return const <Message>[];
      },
      (rows) => rows,
    );
    if (!mounted) return;

    final toReplay = rows
        .where((m) =>
            m.baseId.value == baseId &&
            m.userId.value == userId &&
            _find(m.id.value) == null)
        .map((m) => m.copyWith(syncStatus: SyncStatus.uploading))
        .toList(growable: false);
    if (toReplay.isEmpty) return;

    developer.log(
      'ChatController: replaying ${toReplay.length} outbox entries for '
      'base $baseId',
    );
    state = state.copyWith(pending: [
      ...state.pending,
      ...toReplay.map((m) => PendingSend(message: m)),
    ]);
    unawaited(_replaySequentially(toReplay.map((m) => m.id.value).toList()));
  }

  Future<void> _replaySequentially(List<String> ids) async {
    for (final id in ids) {
      if (!mounted) return;
      await _dispatch(id);
    }
  }

  /// Queue a send. Returns once the pending entry is persisted and the send
  /// has been **started**; completion is reported through state, never
  /// thrown.
  Future<void> send(
    String baseId,
    String userId,
    String content, {
    List<MediaRef> media = const [],
  }) async {
    final message = Message(
      id: MessageId(_uuid.v4()),
      baseId: baseId.bid,
      userId: userId.uid,
      content: content.trim(),
      createdAt: _now(),
      media: List<MediaRef>.unmodifiable(media),
      syncStatus: SyncStatus.uploading,
    );
    developer.log(
      'ChatController: Queueing message ${message.id.value} to base $baseId '
      '(media=${media.length})',
    );

    state = state.copyWith(
      pending: [...state.pending, PendingSend(message: message)],
    );
    await _persist(message);
    unawaited(_dispatch(message.id.value));
  }

  /// Re-send a failed entry with the same id and media.
  Future<void> retry(String messageId) async {
    final entry = _find(messageId);
    if (entry == null || _inFlight.contains(messageId)) return;
    final message = entry.message.copyWith(syncStatus: SyncStatus.uploading);
    _replace(PendingSend(message: message));
    await _persist(message);
    await _dispatch(messageId);
  }

  /// Drop a pending entry without sending it.
  Future<void> discard(String messageId) async {
    if (_inFlight.contains(messageId)) return;
    await _settle(messageId);
  }

  // ---- internals ----

  PendingSend? _find(String id) {
    for (final p in state.pending) {
      if (p.id == id) return p;
    }
    return null;
  }

  void _replace(PendingSend entry) {
    if (!mounted) return;
    state = state.copyWith(
      pending: [
        for (final p in state.pending) p.id == entry.id ? entry : p,
      ],
    );
  }

  bool _feedContains(String id) {
    final feed = state.feed.valueOrNull;
    if (feed == null) return false;
    return feed.messages.any((m) => m.id.value == id);
  }

  Future<void> _persist(Message message) async {
    final res = await _outbox.upsert(message);
    res.match(
      (failure) => developer.log(
        'ChatController: outbox write failed for ${message.id.value} - '
        '${failure.message}',
      ),
      (_) {},
    );
  }

  Future<void> _dispatch(String id) async {
    final entry = _find(id);
    if (entry == null || !_inFlight.add(id)) return;
    try {
      final m = entry.message;
      final res = await _sendMessage(SendMessageParams(
        baseId: m.baseId,
        userId: m.userId,
        content: m.content,
        media: m.media,
        messageId: m.id,
      ));
      if (!mounted) return;
      await res.match(
        (failure) async {
          if (_feedContains(id)) {
            // The document exists — the write landed before this result
            // came back (or a replay raced Firestore's own queue).
            await _settle(id);
            return;
          }
          developer.log('ChatController: Send failed - ${failure.message}');
          await _markFailed(entry, failure);
        },
        (message) async {
          developer.log(
            'ChatController: Message sent successfully - ${message.id.value}',
          );
          await _settle(id);
        },
      );
    } finally {
      _inFlight.remove(id);
    }
  }

  Future<void> _markFailed(PendingSend entry, Failure failure) async {
    final failed = entry.message.copyWith(syncStatus: SyncStatus.failed);
    final next = PendingSend(message: failed, failure: failure);
    if (_find(entry.id) != null) {
      _replace(next);
    } else if (mounted) {
      // Reconciled away by a local echo that the server later rejected —
      // resurface it so the user can act on it.
      state = state.copyWith(pending: [...state.pending, next]);
    }
    if (mounted) {
      state = state.copyWith(
        lastSendFailure: SendFailureEvent(
          seq: ++_failureSeq,
          messageId: failed.id,
          failure: failure,
        ),
      );
    }
    await _persist(failed);
  }

  /// Remove [id] from state and the outbox (both no-ops when absent).
  Future<void> _settle(String id) async {
    if (mounted && _find(id) != null) {
      state = state.copyWith(
        pending: state.pending.where((p) => p.id != id).toList(),
      );
    }
    final res = await _outbox.remove(MessageId(id));
    res.match(
      (failure) => developer.log(
        'ChatController: outbox remove failed for $id - ${failure.message}',
      ),
      (_) {},
    );
  }

  void _reconcileWithFeed(List<Message> feedMessages) {
    if (state.pending.isEmpty) return;
    final ids = feedMessages.map((m) => m.id.value).toSet();
    for (final p in state.pending) {
      if (ids.contains(p.id)) unawaited(_settle(p.id));
    }
  }
}

final chatControllerProvider =
    StateNotifierProvider<ChatController, ChatState>((ref) {
  return ChatController(
    ref.read(sendMessageUseCaseProvider),
    ref.read(streamMessagesUseCaseProvider),
    outbox: ref.read(chatOutboxProvider),
  );
});
