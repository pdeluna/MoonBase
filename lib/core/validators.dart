const int kBaseNameMaxLen = 32;
const int kMessageMaxLen  = 4000;

/// 6 chars, exclude easily-confused O/0/I/1
final RegExp kInviteCode = RegExp(r'^[A-HJ-NP-Z2-9]{6}$');

String normalizeInviteCode(String s) => s.trim().toUpperCase();

bool isValidInviteCode(String s) => kInviteCode.hasMatch(normalizeInviteCode(s));

bool isValidBaseName(String s) {
  final t = s.trim();
  return t.isNotEmpty && t.length <= kBaseNameMaxLen;
}

bool isValidMessage(String s) {
  final t = s.trim();
  return t.isNotEmpty && t.length <= kMessageMaxLen;
}

/// Phase 3 (Slice A) message-payload predicate.
///
/// A chat message is sendable when **either** the trimmed text is non-empty
/// **or** at least one media attachment is staged, and the trimmed text
/// never exceeds [kMessageMaxLen].
///
/// Used by:
/// - `SendMessage` use case to gate the repository call.
/// - `MessageComposer` to enable/disable the send button.
/// - `ChatScreen._sendMessage` for the snackbar guard.
///
/// Keeping the rule in one place ensures the UI cannot disagree with the
/// use case about what "a valid message" is.
bool isValidMessageInput({required String text, required int mediaCount}) {
  final t = text.trim();
  if (t.length > kMessageMaxLen) return false;
  return t.isNotEmpty || mediaCount > 0;
}

/// 1–24 chars: letters, numbers, space, underscore, dot, dash
bool isValidNickname(String s) {
  final t = s.trim();
  if (t.isEmpty || t.length > 24) return false;
  return RegExp(r'^[A-Za-z0-9 _.\-]+$').hasMatch(t);
}

/// Non-empty trimmed email containing `@` with text on both sides.
bool isValidEmail(String s) {
  final t = s.trim();
  if (t.isEmpty) return false;
  final at = t.indexOf('@');
  if (at <= 0 || at == t.length - 1) return false;
  return !t.contains(' ');
}

/// Firebase Email/Password minimum is 6 characters.
bool isValidPassword(String s) => s.length >= 6;
