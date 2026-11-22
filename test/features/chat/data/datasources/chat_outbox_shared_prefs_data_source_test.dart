import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moonbase_skeleton/core/sync_status.dart';
import 'package:moonbase_skeleton/features/chat/data/datasources/chat_outbox_shared_prefs_data_source.dart';
import 'package:moonbase_skeleton/features/chat/data/models/message_model.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_type.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:shared_preferences/shared_preferences.dart';

MessageModel _row(String id, {SyncStatus status = SyncStatus.uploading}) =>
    MessageModel(
      id: id,
      baseId: 'b1',
      userId: 'u1',
      content: 'hello $id',
      createdAt: DateTime.utc(2026, 9, 27, 12),
      media: const [
        MediaRef(
          id: MediaId('img'),
          type: MediaType.image,
          storageKey: 'b1/img.jpg',
          mimeType: 'image/jpeg',
          width: 10,
          height: 20,
        ),
      ],
      syncStatus: status,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late ChatOutboxSharedPrefsDataSource ds;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    ds = ChatOutboxSharedPrefsDataSource(prefs);
  });

  test('empty by default and absent key after the last remove', () async {
    expect(await ds.loadAll(), isEmpty);
    await ds.upsert(_row('a'));
    await ds.remove('a');
    expect(await ds.loadAll(), isEmpty);
    expect(
        prefs.containsKey(ChatOutboxSharedPrefsDataSource.kOutboxKey), isFalse);
  });

  test('round-trips messages including media and syncStatus, oldest first',
      () async {
    await ds.upsert(_row('a'));
    await ds.upsert(_row('b', status: SyncStatus.failed));

    // Re-open from the same prefs to prove it is the persisted bytes.
    final reopened = ChatOutboxSharedPrefsDataSource(prefs);
    final rows = await reopened.loadAll();

    expect(rows.map((r) => r.id), ['a', 'b']);
    expect(rows.first.syncStatus, SyncStatus.uploading);
    expect(rows.last.syncStatus, SyncStatus.failed);
    expect(rows.first.media.single.storageKey, 'b1/img.jpg');
    expect(rows.first.media.single.width, 10);
    expect(rows.first.createdAt, DateTime.utc(2026, 9, 27, 12));
    expect(rows.first.content, 'hello a');
  });

  test('upsert replaces by id in place (status flip keeps order)', () async {
    await ds.upsert(_row('a'));
    await ds.upsert(_row('b'));
    await ds.upsert(_row('a', status: SyncStatus.failed));

    final rows = await ds.loadAll();
    expect(rows.map((r) => r.id), ['a', 'b']);
    expect(rows.first.syncStatus, SyncStatus.failed);
  });

  test('remove of an unknown id is a no-op', () async {
    await ds.upsert(_row('a'));
    await ds.remove('zzz');
    expect((await ds.loadAll()).map((r) => r.id), ['a']);
  });

  test('undecodable rows are skipped, valid rows survive', () async {
    await prefs.setString(
      ChatOutboxSharedPrefsDataSource.kOutboxKey,
      jsonEncode([
        _row('good').toMap(),
        <String, dynamic>{'id': 'bad'},
        'not even a map',
      ]),
    );

    final rows = await ds.loadAll();
    expect(rows.map((r) => r.id), ['good']);
  });

  test('garbage payload reads as empty rather than throwing', () async {
    await prefs.setString(ChatOutboxSharedPrefsDataSource.kOutboxKey, '{}');
    expect(await ds.loadAll(), isEmpty);
  });
}
