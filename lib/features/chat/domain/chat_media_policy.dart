import 'package:moonbase_skeleton/features/media/domain/entities/media_type.dart';

/// Media types supported by the current cloud-chat persistence contract.
///
/// Firebase Storage and Firestore currently persist JPEG image paths only.
/// Keeping this policy in the domain layer gives the picker and send use case
/// one source of truth. Adding video requires changing the Storage path/rules,
/// message codec, upload pipeline, and this set together.
abstract final class ChatMediaPolicy {
  static const Set<MediaType> allowedTypes = <MediaType>{MediaType.image};

  static bool allows(MediaType type) => allowedTypes.contains(type);
}
