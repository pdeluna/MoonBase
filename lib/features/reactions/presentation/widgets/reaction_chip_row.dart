import 'package:flutter/material.dart';
import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction_group.dart';
import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction_kind.dart';
import 'package:moonbase_skeleton/features/reactions/presentation/widgets/reaction_kind_presentation.dart';

/// Dumb chip row under a message/story/comment: one chip per kind with a
/// non-zero count, the current user's kind highlighted. Tapping a chip
/// emits [onTap] (toggle semantics live in the use case).
class ReactionChipRow extends StatelessWidget {
  const ReactionChipRow({
    super.key,
    required this.group,
    this.onTap,
    this.alignEnd = false,
  });

  final ReactionGroup group;
  final ValueChanged<ReactionKind>? onTap;

  /// Right-align for the current user's own bubbles.
  final bool alignEnd;

  static Key chipKey(ReactionKind kind) =>
      ValueKey('reaction-chip-${kind.name}');

  @override
  Widget build(BuildContext context) {
    if (group.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        alignment: alignEnd ? WrapAlignment.end : WrapAlignment.start,
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final entry in group.counts.entries)
            _Chip(
              key: chipKey(entry.key),
              kind: entry.key,
              count: entry.value,
              mine: group.mine == entry.key,
              scheme: scheme,
              onTap: onTap == null ? null : () => onTap!(entry.key),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    super.key,
    required this.kind,
    required this.count,
    required this.mine,
    required this.scheme,
    required this.onTap,
  });

  final ReactionKind kind;
  final int count;
  final bool mine;
  final ColorScheme scheme;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      selected: mine,
      label: '${kind.label} $count${mine ? ', you reacted' : ''}',
      child: Material(
        color: mine
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest.withValues(alpha: 0.7),
        shape: StadiumBorder(
          side: mine
              ? BorderSide(color: scheme.primary, width: 1)
              : BorderSide.none,
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(kind.emoji, style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 4),
                Text(
                  '$count',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: mine ? FontWeight.w700 : FontWeight.w500,
                        color: mine
                            ? scheme.onPrimaryContainer
                            : scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
