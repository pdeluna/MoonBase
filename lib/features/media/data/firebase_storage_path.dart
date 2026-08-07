import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';

/// Sole constructor for Firebase Storage object paths used by MoonBase media.
///
/// Shape (locked Week 5): `bases/{baseId}/media/{uuid}.jpg`
///
/// Matches [`storage.rules`](../../../../storage.rules) path
/// `bases/{baseId}/media/{fileName}` and Firestore `mediaPaths` validation.
/// Leaf is always `.jpg` (task-3 compression output); content-type on the
/// object is the source of truth, not the extension. Picker stays format-open
/// — diverse image picks normalize to JPEG before upload.
///
/// Everything that reads, writes, or deletes cloud media must call this —
/// do not hand-build path strings elsewhere.
String storagePathFor({required BaseId baseId, required String uuid}) =>
    'bases/${baseId.value}/media/$uuid.jpg';

/// UUID hex groups (same shape as Firestore `isValidMediaPath` leaf).
final _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// UUID v4-shaped `.jpg` leaf matching Firestore `isValidMediaPath`.
final _uuidJpgLeaf = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\.jpg$',
);

/// Local picker key: `<baseId>/<uuid>.<ext>` (exactly two path segments).
///
/// Rejects nested paths, `.thumb.jpg` poster siblings, empty segments, and
/// non-UUID leaves — those must fail loudly rather than mint a bad cloud path.
final _localMediaKey = RegExp(
  r'^([^/]+)/([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})\.[A-Za-z0-9]+$',
);

/// True when [path] matches the locked Storage object path for [baseId]
/// (`bases/{baseId}/media/{uuid}.jpg`) — same check as Firestore `mediaPaths`.
bool isFirebaseStoragePathForBase(String path, BaseId baseId) {
  final prefix = 'bases/${baseId.value}/media/';
  if (!path.startsWith(prefix)) return false;
  final leaf = path.substring(prefix.length);
  return _uuidJpgLeaf.hasMatch(leaf);
}

/// Parses `{uuid}` from a path produced by [storagePathFor].
///
/// Returns null if the leaf is not a UUID-shaped `.jpg`.
String? mediaUuidFromStoragePath(String path) {
  final segments = path.split('/');
  if (segments.length != 4) return null;
  if (segments[0] != 'bases' || segments[2] != 'media') return null;
  final leaf = segments[3];
  if (!_uuidJpgLeaf.hasMatch(leaf)) return null;
  return leaf.substring(0, leaf.length - 4);
}

/// Maps a [MediaStorage] key to the locked cloud object path.
///
/// Accepted inputs:
/// - Local picker key: `<baseId>/<uuid>.<ext>` (e.g. `base1/550e8400-….jpg`)
/// - Already-canonical cloud path: `bases/<baseId>/media/<uuid>.jpg`
///
/// On any other shape (empty, `..`, absolute, nested, poster `.thumb.jpg`,
/// non-UUID leaf, wrong segment count): throws [ValidationFailure] — never
/// invents a path the Task 2 Firestore regex would reject.
String cloudStoragePathFromKey(String key) {
  if (key.isEmpty || key.startsWith('/') || key.contains('..')) {
    throw const ValidationFailure('Invalid media storage key.');
  }

  final segments = key.split('/');
  if (segments.length == 4 &&
      segments[0] == 'bases' &&
      segments[2] == 'media') {
    final baseId = BaseId(segments[1]);
    if (!isFirebaseStoragePathForBase(key, baseId)) {
      throw const ValidationFailure('Invalid cloud media storage path.');
    }
    return key;
  }

  final match = _localMediaKey.firstMatch(key);
  if (match == null) {
    throw const ValidationFailure(
      'Invalid media storage key; expected "<baseId>/<uuid>.<ext>".',
    );
  }
  final baseId = match.group(1)!;
  final uuid = match.group(2)!;
  if (baseId.isEmpty || !_uuid.hasMatch(uuid)) {
    throw const ValidationFailure('Invalid media storage key.');
  }
  return storagePathFor(baseId: BaseId(baseId), uuid: uuid);
}
