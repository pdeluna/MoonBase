class InviteCode {
  const InviteCode(this.value);

  final String value;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InviteCode && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
