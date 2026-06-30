enum BaseRole {
  owner,
  admin,
  member;

  bool get isOwnerOrAdmin => this == BaseRole.owner || this == BaseRole.admin;
}
