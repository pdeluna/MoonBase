import 'package:flutter/material.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/calendar_tokens.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';
import 'package:moonbase_skeleton/features/media/presentation/widgets/media_tile.dart';

/// Today's shared media. The caller hides it when [tiles] is empty.
class SharedTodaySection extends StatelessWidget {
  const SharedTodaySection({
    super.key,
    required this.tiles,
    required this.keptUntil,
  });

  static const sectionKey = Key('calendar-shared-today');

  final List<MediaRef> tiles;
  final DateTime? keptUntil;

  @override
  Widget build(BuildContext context) {
    final tokens = CalendarTokens.of(context);
    final l10n = MaterialLocalizations.of(context);
    final until = keptUntil;
    final caption = until == null
        ? null
        : 'Kept until ${l10n.formatTimeOfDay(TimeOfDay.fromDateTime(until.toLocal()))} tomorrow, then moved to this day on the calendar.';
    return Padding(
      key: sectionKey,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('SHARED TODAY', style: CalendarTokens.overline(context)),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 3 / 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final tile in tiles)
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: tokens.border),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: MediaTile(
                      media: tile,
                      fit: BoxFit.cover,
                      borderRadius: const BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                ),
            ],
          ),
          if (caption != null) ...[
            const SizedBox(height: 8),
            Text(
              caption,
              style: TextStyle(fontSize: 12, color: tokens.secondary),
            ),
          ],
        ],
      ),
    );
  }
}
