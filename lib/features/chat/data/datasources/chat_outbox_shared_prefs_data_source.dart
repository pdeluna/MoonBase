import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:moonbase_skeleton/features/chat/data/datasources/chat_outbox_local_data_source.dart';
import 'package:moonbase_skeleton/features/chat/data/models/message_model.dart';

/// SharedPreferences-backed chat outbox.
///
/// Same persistence pattern as `ChatSharedPrefsDataSource` /
/// `BaseSharedPrefsDataSource`: one `mb.*` key holding a JSON-encoded list
/// of [MessageModel.toMap] rows (media via `MediaRefCodec`, `syncStatus` as
/// the enum name). The outbox is expected to hold a handful of entries at
/// most, so a single key rewritten on every change is adequate; a dedicated
/// database would be a new dependency for no measurable gain.
///
/// Rows that fail to decode are dropped on read (same posture as the chat
/// prefs source) rather than poisoning every later send.
class ChatOutboxSharedPrefsDataSource implements ChatOutboxLocalDataSource {
  ChatOutboxSharedPrefsDataSource(this._prefs);

  static const kOutboxKey = 'mb.chatOutbox';

  final SharedPreferences _prefs;

  List<Map<String, dynamic>> _readRows() {
    final raw = _prefs.getString(kOutboxKey);
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return <Map<String, dynamic>>[];
    return decoded.whereType<Map<String, dynamic>>().toList();
  }

  Future<void> _writeRows(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) {
      await _prefs.remove(kOutboxKey);
      return;
    }
    await _prefs.setString(kOutboxKey, jsonEncode(rows));
  }

  @override
  Future<List<MessageModel>> loadAll() async {
    final out = <MessageModel>[];
    for (final row in _readRows()) {
      try {
        out.add(MessageModel.fromMap(row));
      } catch (_) {
        // Skip undecodable rows; see class doc.
      }
    }
    return out;
  }

  @override
  Future<void> upsert(MessageModel message) async {
    final rows = _readRows();
    final index = rows.indexWhere((r) => r['id'] == message.id);
    final encoded = message.toMap();
    if (index == -1) {
      rows.add(encoded);
    } else {
      rows[index] = encoded;
    }
    await _writeRows(rows);
  }

  @override
  Future<void> remove(String messageId) async {
    final rows = _readRows();
    final before = rows.length;
    rows.removeWhere((r) => r['id'] == messageId);
    if (rows.length != before) await _writeRows(rows);
  }
}
