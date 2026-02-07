import 'package:flutter/material.dart';

class MessageTileVM {
    const MessageTileVM({
    required this.id,
    required this.text,
    required this.sentAt,
    required this.isMine,
    required this.nickname,
    required this.nameColor,
    this.avatarUrl,
  });
  
  final String id;
  final String text;
  final DateTime sentAt;
  final bool isMine;
  final String nickname;
  final Color nameColor;
  final String? avatarUrl;

}
