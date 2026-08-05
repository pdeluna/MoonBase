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

/// UUID v4-shaped leaf (hex groups) matching Firestore `isValidMediaPath`.
final _uuidJpgLeaf = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\.jpg$',
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
