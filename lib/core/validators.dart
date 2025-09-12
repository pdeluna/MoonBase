const int kBaseNameMaxLen = 32;
const int kMessageMaxLen  = 1000;

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

/// 1–24 chars: letters, numbers, space, underscore, dot, dash
bool isValidNickname(String s) {
  final t = s.trim();
  if (t.isEmpty || t.length > 24) return false;
  return RegExp(r'^[A-Za-z0-9 _.\-]+$').hasMatch(t);
}
