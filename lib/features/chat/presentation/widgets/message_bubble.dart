import 'package:flutter/material.dart';
import 'package:moonbase_skeleton/features/chat/presentation/viewmodels/message_tile_vm.dart';

class MessageBubble extends StatelessWidget {
    const MessageBubble({super.key, required this.vm});
  final MessageTileVM vm;

  @override
  Widget build(BuildContext context) {
    final align = vm.isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final radius = BorderRadius.circular(14);
    return RepaintBoundary(
      child: Align(
        key: ValueKey(vm.id),
        alignment: vm.isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75, // 75% of screen width
            minWidth: 60, // Minimum width for very short messages
          ),
          child: Column(
            crossAxisAlignment: align,
            children: [
              // bubble with sender name inside
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: vm.isMine
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: radius,
                ),
                child: IntrinsicWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // sender name (only for other users)
                      if (!vm.isMine) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 8,
                              backgroundColor: vm.nameColor,
                              child: Text(
                                vm.nickname.substring(0, 1).toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                vm.nickname,
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: vm.nameColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],
                      // message text
                      Text(
                        vm.text,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: vm.isMine 
                            ? Theme.of(context).colorScheme.onPrimary 
                            : Theme.of(context).colorScheme.onSurface,
                        ),
                        softWrap: true,
                        overflow: TextOverflow.visible,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
