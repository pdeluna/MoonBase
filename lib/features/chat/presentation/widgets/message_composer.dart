import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/core/validators.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_constraints.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';
import 'package:moonbase_skeleton/features/media/presentation/widgets/media_picker_sheet.dart';
import 'package:moonbase_skeleton/features/media/presentation/widgets/media_tile.dart';

/// Composer for sending a chat message.
///
/// Phase 3 (Slice A) additions:
///
/// 1. Leading attach button → opens `MediaPickerSheet`; on success the
///    picked `MediaRef` is appended to the parent-owned [stagedMedia] list
///    via [onStage]. Disabled when `stagedMedia.length == [maxMedia]`.
/// 2. Horizontal preview strip above the text field rendering each
///    `MediaTile` with a tap-target × that calls [onUnstage]. Hidden when
///    `stagedMedia` is empty so the existing text-only UX is unchanged.
/// 3. Send is enabled when `widget.canSend && (text non-empty || staged
///    non-empty) && text length ≤ kMessageMaxLen`, mirroring
///    `isValidMessageInput`.
///
/// The composer remains a "dumb tile": it never reads Riverpod state
/// directly. The picker sheet does — and that is explicitly sanctioned
/// for the foundation `media` slice (see Phase 3 architectural rule #3
/// in `docs/PHASE3_DOD_ACTION_LIST.md`).
class MessageComposer extends ConsumerStatefulWidget {
  const MessageComposer({
    super.key,
    required this.messageController,
    required this.onSendMessage,
    required this.canSend,
    required this.baseId,
    required this.stagedMedia,
    required this.onStage,
    required this.onUnstage,
    this.maxMedia = MediaConstraints.maxMediaPerMessageDefault,
  });

  final TextEditingController messageController;
  final VoidCallback onSendMessage;

  /// External "is the user authenticated and a base selected" predicate.
  /// Internal text+media validity is checked on top of this.
  final bool canSend;

  final BaseId baseId;
  final List<MediaRef> stagedMedia;
  final void Function(MediaRef) onStage;
  final void Function(MediaRef) onUnstage;
  final int maxMedia;

  @override
  ConsumerState<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends ConsumerState<MessageComposer> {
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

  bool get _hasValidInput => isValidMessageInput(
        text: widget.messageController.text,
        mediaCount: widget.stagedMedia.length,
      );

  bool get _attachEnabled =>
      widget.canSend && widget.stagedMedia.length < widget.maxMedia;

  Future<void> _openPicker() async {
    final remaining = widget.maxMedia - widget.stagedMedia.length;
    if (remaining <= 0) return;

    final picked = await MediaPickerSheet.show(
      context,
      widget.baseId,
      remainingSlots: remaining,
    );
    if (!mounted || picked.isEmpty) return;

    for (final ref in picked) {
      if (widget.stagedMedia.length >= widget.maxMedia) break;
      widget.onStage(ref);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canSend = widget.canSend && _hasValidInput;
    final fillColor = widget.canSend
        ? theme.colorScheme.surfaceContainerHighest
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.stagedMedia.isNotEmpty) ...[
              _StagedMediaStrip(
                staged: widget.stagedMedia,
                onUnstage: widget.onUnstage,
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                IconButton(
                  tooltip: _attachEnabled
                      ? 'Attach media'
                      : widget.stagedMedia.length >= widget.maxMedia
                          ? 'Max ${widget.maxMedia} attachments'
                          : 'Select a base to attach',
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  onPressed: _attachEnabled ? _openPicker : null,
                ),
                Expanded(
                  child: TextField(
                    controller: widget.messageController,
                    enabled: widget.canSend,
                    decoration: InputDecoration(
                      hintText: widget.canSend
                          ? widget.stagedMedia.isEmpty
                              ? 'Type a message...'
                              : 'Add a caption (optional)...'
                          : 'Select a base to chat',
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: fillColor,
                    ),
                    onSubmitted: canSend ? (_) => widget.onSendMessage() : null,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: null,
                    maxLength: kMessageMaxLen,
                    buildCounter: (context,
                        {required currentLength,
                        required isFocused,
                        maxLength}) {
                      if (currentLength > kMessageMaxLen * 0.8) {
                        return Text(
                          '$currentLength/$kMessageMaxLen',
                          style: TextStyle(
                            color: theme.colorScheme.error,
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
          ],
        ),
      ),
    );
  }
}

/// Horizontal strip of staged media tiles with a per-item × to unstage.
class _StagedMediaStrip extends StatelessWidget {
  const _StagedMediaStrip({
    required this.staged,
    required this.onUnstage,
  });

  final List<MediaRef> staged;
  final void Function(MediaRef) onUnstage;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: staged.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final item = staged[i];
          return _StagedThumb(
            media: item,
            onRemove: () => onUnstage(item),
          );
        },
      ),
    );
  }
}

class _StagedThumb extends StatelessWidget {
  const _StagedThumb({required this.media, required this.onRemove});

  final MediaRef media;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          width: 72,
          height: 72,
          child: MediaTile(media: media),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: Material(
            color: Colors.black.withValues(alpha: 0.6),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onRemove,
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
