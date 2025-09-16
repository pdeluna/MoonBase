import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:moonbase_skeleton/features/chat/presentation/providers/message_tile_vm_provider.dart';
import 'package:moonbase_skeleton/features/chat/presentation/widgets/message_bubble.dart';
import 'package:moonbase_skeleton/features/chat/domain/providers/visible_message_ids_provider.dart';
import 'package:moonbase_skeleton/core/ids.dart';

class ChatThread extends ConsumerWidget {
  const ChatThread({super.key, required this.baseId});
  final String baseId; // the current base/room

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idsAsync = ref.watch(visibleMessageIdsProvider(baseId.bid));

    return idsAsync.when(
      data: (ids) {
        if (ids.isEmpty) {
          return const Center(
            child: Text(
              'No messages yet. Start the conversation!',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          );
        }

        return ListView.builder(
          reverse: true, // newest at bottom or top per your UX
          itemCount: ids.length,
          itemBuilder: (context, i) {
            final id = ids[i];
            final vm = ref.watch(messageTileVmProvider(id));
            if (vm == null) return const SizedBox.shrink();
            return MessageBubble(key: ValueKey(id.value), vm: vm);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('Error loading messages: $error'),
      ),
    );
  }
}
