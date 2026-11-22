import 'package:flutter/material.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/viewmodels/calendar_home_vm.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/calendar_tokens.dart';

/// "TODAY", the medium date, and the story-capture button.
class DateHeading extends StatelessWidget {
  const DateHeading({super.key, required this.today, required this.onShare});

  static const shareKey = Key('calendar-share-story');

  final DayKey today;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final tokens = CalendarTokens.of(context);
    final date = MaterialLocalizations.of(context).formatMediumDate(
      today.localMidnight,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TODAY', style: CalendarTokens.overline(context)),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.57,
                    height: 1.1,
                    color: tokens.ink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Semantics(
            button: true,
            label: 'Share a story',
            child: ExcludeSemantics(
              child: Material(
                color: CalendarTokens.accent,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: shareKey,
                  onTap: onShare,
                  child: const SizedBox(
                    width: 48,
                    height: 48,
                    child: Icon(Icons.add, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
