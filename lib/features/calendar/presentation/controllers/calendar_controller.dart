import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_event.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_feed.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_settings.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/event_input.dart';
import 'package:moonbase_skeleton/features/calendar/domain/usecases/create_event.dart';
import 'package:moonbase_skeleton/features/calendar/domain/usecases/delete_event.dart';
import 'package:moonbase_skeleton/features/calendar/domain/usecases/get_calendar_settings.dart';
import 'package:moonbase_skeleton/features/calendar/domain/usecases/set_calendar_settings.dart';
import 'package:moonbase_skeleton/features/calendar/domain/usecases/update_event.dart';
import 'package:moonbase_skeleton/features/calendar/domain/usecases/watch_events.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/providers/calendar_providers.dart';

class CalendarState {
  const CalendarState({
    this.baseId,
    this.feed = const AsyncValue<CalendarFeed>.loading(),
    this.settings = CalendarSettings.defaults,
    this.settingsFailure,
  });

  /// Base the current subscription belongs to; null when idle.
  final String? baseId;
  final AsyncValue<CalendarFeed> feed;

  /// Settings in effect for [baseId]. Falls back to `CalendarSettings.defaults`
  /// when the settings read failed (see [settingsFailure]).
  final CalendarSettings settings;

  /// Non-null when `getSettings` returned `Left` and defaults are in use.
  final Failure? settingsFailure;

  CalendarState copyWith({
    String? baseId,
    AsyncValue<CalendarFeed>? feed,
    CalendarSettings? settings,
    Failure? settingsFailure,
    bool clearSettingsFailure = false,
  }) =>
      CalendarState(
        baseId: baseId ?? this.baseId,
        feed: feed ?? this.feed,
        settings: settings ?? this.settings,
        settingsFailure: clearSettingsFailure
            ? null
            : (settingsFailure ?? this.settingsFailure),
      );
}

/// Owns the live feed subscription for the selected base.
///
/// `load(baseId)` reads settings (bounded get), then subscribes to the window
/// they describe; a later `load`/`clear` cancels the previous subscription.
/// Mutations `match` the `Either` and return `Failure?` — they never throw.
class CalendarController extends StateNotifier<CalendarState> {
  CalendarController({
    required WatchEvents watchEvents,
    required CreateEvent createEvent,
    required UpdateEvent updateEvent,
    required DeleteEvent deleteEvent,
    required GetCalendarSettings getSettings,
    required SetCalendarSettings setSettings,
    DateTime Function()? now,
  })  : _watchEvents = watchEvents,
        _createEvent = createEvent,
        _updateEvent = updateEvent,
        _deleteEvent = deleteEvent,
        _getSettings = getSettings,
        _setSettings = setSettings,
        _now = now ?? DateTime.now,
        super(const CalendarState());

  final WatchEvents _watchEvents;
  final CreateEvent _createEvent;
  final UpdateEvent _updateEvent;
  final DeleteEvent _deleteEvent;
  final GetCalendarSettings _getSettings;
  final SetCalendarSettings _setSettings;
  final DateTime Function() _now;

  StreamSubscription<CalendarFeed>? _sub;
  int _loadToken = 0;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  /// Settings first (bounded), then the feed. If the settings read fails the
  /// feed still opens with defaults so a cached agenda can render (R5).
  Future<void> load(String baseId) async {
    final token = ++_loadToken;
    await _sub?.cancel();
    _sub = null;
    state = CalendarState(baseId: baseId);

    developer.log('CalendarController: loading settings for base $baseId');
    final settingsRes = await _getSettings(baseId.bid);
    if (token != _loadToken) return; // superseded by a newer load/clear

    final settings = settingsRes.match(
      (failure) {
        developer.log(
          'CalendarController: settings read failed (${failure.message}); '
          'using defaults',
        );
        state = state.copyWith(settingsFailure: failure);
        return CalendarSettings.defaults;
      },
      (s) {
        state = state.copyWith(settings: s, clearSettingsFailure: true);
        return s;
      },
    );
    _subscribe(baseId, settings, token);
  }

  void _subscribe(String baseId, CalendarSettings settings, int token) {
    _sub?.cancel();
    final range = settings.window.resolve(_now());
    developer.log('CalendarController: watching $baseId in $range');
    _sub = _watchEvents(baseId: baseId.bid, range: range).listen(
      (feed) {
        if (token != _loadToken) return;
        state = state.copyWith(feed: AsyncValue.data(feed));
      },
      onError: (Object error, StackTrace st) {
        if (token != _loadToken) return;
        state = state.copyWith(feed: AsyncValue.error(error, st));
      },
    );
  }

  /// Re-open the feed for the current base (Retry affordance).
  Future<void> reload() async {
    final baseId = state.baseId;
    if (baseId != null) await load(baseId);
  }

  /// No base selected: drop the subscription and reset.
  void clear() {
    _loadToken++;
    _sub?.cancel();
    _sub = null;
    state = const CalendarState();
  }

  Future<Failure?> create({
    required Base base,
    required UserId requester,
    required EventInput input,
  }) async {
    final res = await _createEvent(CreateEventParams(
      base: base,
      requester: requester,
      settings: state.settings,
      input: input,
    ));
    return res.match((f) => f, (_) => null);
  }

  Future<Failure?> update({
    required Base base,
    required UserId requester,
    required CalendarEvent existing,
    required EventInput input,
  }) async {
    final res = await _updateEvent(UpdateEventParams(
      base: base,
      requester: requester,
      existing: existing,
      window: state.settings.window,
      input: input,
    ));
    return res.match((f) => f, (_) => null);
  }

  Future<Failure?> delete({
    required Base base,
    required UserId requester,
    required CalendarEvent event,
  }) async {
    final res = await _deleteEvent(DeleteEventParams(
      base: base,
      requester: requester,
      event: event,
    ));
    return res.match((f) => f, (_) => null);
  }

  /// Owner saves window + policy; on success the feed re-subscribes with the
  /// new window so the agenda shrinks/grows immediately.
  Future<Failure?> saveSettings({
    required Base base,
    required UserId requester,
    required CalendarSettings settings,
  }) async {
    final res = await _setSettings(SetCalendarSettingsParams(
      base: base,
      requester: requester,
      settings: settings,
    ));
    return res.match(
      (f) => f,
      (written) {
        final baseId = state.baseId;
        if (baseId == base.id.value) {
          state = state.copyWith(
            settings: written,
            feed: const AsyncValue<CalendarFeed>.loading(),
            clearSettingsFailure: true,
          );
          _subscribe(base.id.value, written, ++_loadToken);
        }
        return null;
      },
    );
  }
}

final calendarControllerProvider =
    StateNotifierProvider<CalendarController, CalendarState>((ref) {
  return CalendarController(
    watchEvents: ref.read(watchEventsUseCaseProvider),
    createEvent: ref.read(createEventUseCaseProvider),
    updateEvent: ref.read(updateEventUseCaseProvider),
    deleteEvent: ref.read(deleteEventUseCaseProvider),
    getSettings: ref.read(getCalendarSettingsUseCaseProvider),
    setSettings: ref.read(setCalendarSettingsUseCaseProvider),
  );
});
