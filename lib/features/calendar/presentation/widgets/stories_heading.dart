import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonbase_skeleton/core/presentation/debug_error_details.dart';
import 'package:moonbase_skeleton/features/auth/presentation/providers/member_presentation_provider.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/providers/stories_seam.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/calendar_tokens.dart';

/// Story authors for today: skeleton, error, nothing, or the bubble row.
class StoriesHeading extends ConsumerWidget {
  const StoriesHeading({super.key});

  static const rowKey = Key('calendar-stories-row');
  static const skeletonKey = Key('calendar-stories-skeleton');
  static const errorKey = Key('calendar-stories-error');
  static const retryKey = Key('calendar-stories-retry');

  static const errorCopy = "Couldn't load stories.";

  /// 62px slot, 7px gap, and room for the 11px label. Skeleton and bubbles
  /// share it so the row does not jump.
  static const rowHeight = 85.0;
  static const slotSize = 62.0;
  static const avatarSize = 54.0;
  static const bubbleGap = 18.0;
  static const labelGap = 7.0;
  static const skeletonSize = 50.0;
  static const skeletonCount = 3;

  static Key bubbleKey(String userId) =>
      ValueKey<String>('calendar-story-bubble-$userId');

  static Key ringKey(String userId) =>
      ValueKey<String>('calendar-story-ring-$userId');

  static Key skeletonDotKey(int index) =>
      ValueKey<String>('calendar-stories-skeleton-$index');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stories = ref.watch(storiesHeadingProvider);
    return stories.when(
      loading: () => const _StoriesSkeleton(),
      error: (error, stackTrace) => _StoriesError(
        error: error,
        stackTrace: stackTrace,
        onRetry: () => ref.invalidate(storiesHeadingProvider),
      ),
      data: (data) {
        if (data.authors.isEmpty) return const SizedBox.shrink();
        return _BubbleRow(authors: data.authors);
      },
    );
  }
}

class _BubbleRow extends StatelessWidget {
  const _BubbleRow({required this.authors});

  final List<StoriesHeadingAuthor> authors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: SizedBox(
        key: StoriesHeading.rowKey,
        height: StoriesHeading.rowHeight,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              for (var i = 0; i < authors.length; i++) ...[
                if (i > 0) const SizedBox(width: StoriesHeading.bubbleGap),
                _StoryBubble(author: authors[i]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StoryBubble extends ConsumerWidget {
  const _StoryBubble({required this.author});

  final StoriesHeadingAuthor author;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = CalendarTokens.of(context);
    final member = ref.watch(
      memberPresentationProvider(author.userId.value),
    );
    final nickname = member.nickname;
    final initial = nickname.isEmpty ? '?' : nickname[0].toUpperCase();
    return Column(
      key: StoriesHeading.bubbleKey(author.userId.value),
      children: [
        SizedBox(
          width: StoriesHeading.slotSize,
          height: StoriesHeading.slotSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (!author.opened)
                DecoratedBox(
                  key: StoriesHeading.ringKey(author.userId.value),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: CalendarTokens.accent,
                      width: 2,
                    ),
                  ),
                  child: const SizedBox.expand(),
                ),
              SizedBox.square(
                dimension: StoriesHeading.avatarSize,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: member.nameColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: StoriesHeading.labelGap),
        SizedBox(
          width: StoriesHeading.slotSize,
          child: Text(
            nickname,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              height: 1.0,
              fontWeight: author.opened ? FontWeight.w400 : FontWeight.w500,
              color: author.opened ? tokens.secondary : tokens.ink,
            ),
          ),
        ),
      ],
    );
  }
}

class _StoriesSkeleton extends StatelessWidget {
  const _StoriesSkeleton();

  @override
  Widget build(BuildContext context) {
    final color = CalendarTokens.of(context).skeleton;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: SizedBox(
        key: StoriesHeading.skeletonKey,
        height: StoriesHeading.rowHeight,
        child: Row(
          children: [
            for (var i = 0; i < StoriesHeading.skeletonCount; i++) ...[
              if (i > 0) const SizedBox(width: StoriesHeading.bubbleGap),
              SizedBox(
                width: StoriesHeading.slotSize,
                height: StoriesHeading.slotSize,
                child: Center(
                  child: SizedBox.square(
                    key: StoriesHeading.skeletonDotKey(i),
                    dimension: StoriesHeading.skeletonSize,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StoriesError extends StatelessWidget {
  const _StoriesError({
    required this.error,
    required this.stackTrace,
    required this.onRetry,
  });

  final Object error;
  final StackTrace stackTrace;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final secondary = CalendarTokens.of(context).secondary;
    return DebugErrorDetails(
      error: error,
      stackTrace: stackTrace,
      child: Padding(
        key: StoriesHeading.errorKey,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Row(
          children: [
            Expanded(
              child: Text(
                StoriesHeading.errorCopy,
                style: TextStyle(fontSize: 13, color: secondary),
              ),
            ),
            TextButton(
              key: StoriesHeading.retryKey,
              style: TextButton.styleFrom(
                foregroundColor: CalendarTokens.accent,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(44, 44),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
