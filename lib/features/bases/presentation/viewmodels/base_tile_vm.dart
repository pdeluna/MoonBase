import 'package:flutter/material.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base.dart';

class BaseTileVM {
  const BaseTileVM({
    required this.id,
    required this.name,
    required this.ownerUserId,
    required this.createdAt,
    required this.isSelected,
    required this.isOwner,
    required this.avatarColor,
  });
  
  factory BaseTileVM.fromBase(Base base, {required bool isSelected, required bool isOwner, required Color avatarColor}) {
    return BaseTileVM(
      id: base.id.value,
      name: base.name,
      ownerUserId: base.ownerUserId.value,
      createdAt: base.createdAt,
      isSelected: isSelected,
      isOwner: isOwner,
      avatarColor: avatarColor,
    );
  }

  final String id;
  final String name;
  final String ownerUserId;
  final DateTime createdAt;
  final bool isSelected;
  final bool isOwner;
  final Color avatarColor;
}
