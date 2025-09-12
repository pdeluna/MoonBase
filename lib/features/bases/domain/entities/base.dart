import 'package:moonbase_skeleton/core/ids.dart';

class Base {

  const Base({required this.id, required this.name, required this.ownerUserId, required this.createdAt});

  final BaseId id;
  final String name;
  final UserId ownerUserId;
  final DateTime createdAt;


  Base copyWith({String? name}) => Base(
    id: id,
    name: name ?? this.name,
    ownerUserId: ownerUserId,
    createdAt: createdAt,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Base &&
        other.id == id &&
        other.name == name &&
        other.ownerUserId == ownerUserId &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(id, name, ownerUserId, createdAt);
  }

  @override
  String toString() {
    return 'Base(id: $id, name: $name, ownerUserId: $ownerUserId, createdAt: $createdAt)';
  }
}
