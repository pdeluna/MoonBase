import 'package:moonbase_skeleton/features/media/domain/repositories/media_storage.dart';

/// Base type for cloud-backed [MediaStorage] implementations.
///
/// Concrete impl: [FirebaseMediaStorage] — compress + upload + download URL
/// resolve via Firebase Storage. Widgets resolve through
/// `ResolvingMediaStorage` on [mediaStorageProvider]; `SendMessage` uploads
/// via [cloudMediaStorageProvider].
///
/// ## Pass-2 handoff (required)
///
/// [MediaStorage.putBytes] returns [Future] and throws typed [Failure]s.
/// Pass 2 send orchestration **must** wrap every cloud `putBytes` in
/// `guard(...)`. An unguarded call will throw and crash the send flow.
///
/// See `docs/PHASE3_DOD_ACTION_LIST.md` §0.3.5 and
/// `docs/FIRESTORE_SCHEMA.md` (Storage / task 3 notes).
abstract class RemoteMediaStorage implements MediaStorage {
  const RemoteMediaStorage();
}
