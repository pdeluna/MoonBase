import 'package:flutter_test/flutter_test.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/core/sync_status.dart';
import 'package:moonbase_skeleton/features/chat/domain/entities/message.dart';
import 'package:moonbase_skeleton/features/chat/presentation/viewmodels/chat_screen_vm.dart';

Message _m(String id, int minute, {SyncStatus status = SyncStatus.synced}) =>
    Message(
      id: MessageId(id),
      baseId: 'b1'.bid,
      userId: 'u1'.uid,
      content: id,
      createdAt: DateTime.utc(2026, 9, 27, 12, minute),
      syncStatus: status,
    );

void main() {
  group('ChatScreenVM.mergePending', () {
    test(
        'pending entries not in the feed are appended and sorted newest '
        'first', () {
      final feed = [_m('f2', 20), _m('f1', 10)];
      final pending = [
        _m('p1', 15, status: SyncStatus.uploading),
        _m('p2', 30, status: SyncStatus.failed),
      ];

      final merged = ChatScreenVM.mergePending(feed, pending);

      expect(merged.map((m) => m.id.value), ['p2', 'f2', 'p1', 'f1']);
      expect(merged[0].syncStatus, SyncStatus.failed);
      expect(merged[2].syncStatus, SyncStatus.uploading);
    });

    test('the feed copy wins over a pending copy with the same id', () {
      final feed = [_m('same', 20)];
      final pending = [_m('same', 25, status: SyncStatus.uploading)];

      final merged = ChatScreenVM.mergePending(feed, pending);

      expect(merged, hasLength(1));
      expect(merged.single.syncStatus, SyncStatus.synced);
      expect(merged.single.createdAt, DateTime.utc(2026, 9, 27, 12, 20));
    });

    test('empty inputs yield an empty, unmodifiable list', () {
      final merged = ChatScreenVM.mergePending(const [], const []);
      expect(merged, isEmpty);
      expect(() => merged.add(_m('x', 1)), throwsUnsupportedError);
    });
  });
}
