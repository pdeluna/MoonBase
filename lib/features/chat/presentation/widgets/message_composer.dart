import 'package:flutter/material.dart';
import 'package:moonbase_skeleton/core/validators.dart';

class MessageComposer extends StatefulWidget {
  const MessageComposer({
    super.key,
    required this.messageController,
    required this.onSendMessage,
    required this.canSend,
  });

  final TextEditingController messageController;
  final VoidCallback onSendMessage;
  final bool canSend;

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<MessageComposer> {
  @override
  void initState() {
    super.initState();
    widget.messageController.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(MessageComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.messageController != widget.messageController) {
      oldWidget.messageController.removeListener(_onTextChanged);
      widget.messageController.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    widget.messageController.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
  }

  bool get _hasValidText =>
      isValidMessage(widget.messageController.text.trim());

  @override
  Widget build(BuildContext context) {
    final canSend = widget.canSend && _hasValidText;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: widget.messageController,
                enabled: widget.canSend,
                decoration: InputDecoration(
                  hintText: widget.canSend
                      ? 'Type a message...'
                      : 'Select a base to chat',
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: widget.canSend
                      ? Theme.of(context).colorScheme.surfaceContainerHighest
                      : Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.5),
                ),
                onSubmitted: canSend ? (_) => widget.onSendMessage() : null,
                textCapitalization: TextCapitalization.sentences,
                maxLines: null,
                maxLength: kMessageMaxLen,
                buildCounter: (context,
                    {required currentLength, required isFocused, maxLength}) {
                  if (currentLength > kMessageMaxLen * 0.8) {
                    return Text(
                      '$currentLength/$kMessageMaxLen',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    );
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 8),
            FloatingActionButton.small(
              onPressed: canSend ? widget.onSendMessage : null,
              child: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
