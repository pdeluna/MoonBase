import 'package:flutter/material.dart';
import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction_kind.dart';
import 'package:moonbase_skeleton/features/reactions/presentation/widgets/reaction_kind_presentation.dart';

/// Six-kind picker shown on long-press. Returns the tapped kind or null on
/// dismiss; the caller decides toggle-vs-replace via the use case.
class ReactionPickerSheet extends StatelessWidget {
  const ReactionPickerSheet({super.key, this.current});

  /// The user's existing reaction on the target (highlighted).
  final ReactionKind? current;

  static Key optionKey(ReactionKind kind) =>
      ValueKey('reaction-pick-${kind.name}');

  static Future<ReactionKind?> show(
    BuildContext context, {
    ReactionKind? current,
  }) {
    return showModalBottomSheet<ReactionKind>(
      context: context,
      showDragHandle: true,
      builder: (_) => ReactionPickerSheet(current: current),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              current == null
                  ? 'React'
                  : 'Tap ${current!.label} again to remove',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final kind in ReactionKind.values)
                  _Option(
                    key: optionKey(kind),
                    kind: kind,
                    selected: kind == current,
                    scheme: scheme,
                    onTap: () => Navigator.of(context).pop(kind),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    super.key,
    required this.kind,
    required this.selected,
    required this.scheme,
    required this.onTap,
  });

  final ReactionKind kind;
  final bool selected;
  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: kind.label,
      child: Material(
        color: selected ? scheme.primaryContainer : Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text(kind.emoji, style: const TextStyle(fontSize: 28)),
          ),
        ),
      ),
    );
  }
}
