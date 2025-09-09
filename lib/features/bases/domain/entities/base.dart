class Base {
  final String id;
  final String name;
  final String ownerUserId;
  final DateTime createdAt;

  const Base({
    required this.id,
    required this.name,
    required this.ownerUserId,
    required this.createdAt,
  });

  Base copyWith({String? name}) => Base(
    id: id,
    name: name ?? this.name,
    ownerUserId: ownerUserId,
    createdAt: createdAt,
  );
}
