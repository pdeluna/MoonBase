import 'package:flutter/material.dart';
import 'package:moonbase_skeleton/features/chat/domain/entities/message.dart';
import 'package:moonbase_skeleton/core/user_color_utils.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.currentUserId,
    this.senderNickname,
    this.senderColor,
  });

  final Message message;
  final String? currentUserId;
  final String? senderNickname;
  final Color? senderColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isMine = currentUserId != null && currentUserId == message.userId.value;
    final nameColor = senderColor ?? UserColorUtils.getColorForUserId(message.userId.value);
    final nickname = (senderNickname?.isNotEmpty ?? false) ? senderNickname! : 'Unknown';
    final displayName = nickname;
    final initial = nickname == 'Unknown' ? '?' : nickname.substring(0, 1).toUpperCase();

    return RepaintBoundary(
      key: ValueKey(message.id.value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        child: Row(
          mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (isMine) const SizedBox(width: 48),
            if (!isMine) _Avatar(initial: initial, color: nameColor),
            if (!isMine) const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayName,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: nameColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isMine
                          ? scheme.primaryContainer.withValues(alpha: 0.6)
                          : scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      message.content,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isMine ? scheme.onPrimaryContainer : scheme.onSurface,
                        height: 1.35,
                      ),
                      softWrap: true,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                ],
              ),
            ),
            if (!isMine) const SizedBox(width: 48),
            if (isMine) const SizedBox(width: 12),
            if (isMine) _Avatar(initial: initial, color: nameColor),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initial, required this.color});

  final String initial;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: CircleAvatar(
        radius: 16,
        backgroundColor: color,
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
