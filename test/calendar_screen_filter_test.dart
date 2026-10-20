import 'package:calendar/models/schedule_event.dart';
import 'package:calendar/screens/calendar_screen.dart';
import 'package:calendar/utils/search_period.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final events = [
    ScheduleEvent(id: 'day', title: '会議 A', date: DateTime(2026, 10, 20), hasTime: true, hour: 15),
    ScheduleEvent(id: 'dayEarly', title: '朝会', date: DateTime(2026, 10, 20), hasTime: true, hour: 9),
    ScheduleEvent(id: 'week', title: '会議 B', date: DateTime(2026, 10, 24), isCompleted: true),
    ScheduleEvent(id: 'month', title: '会議 C', date: DateTime(2026, 10, 2)),
    ScheduleEvent(id: 'year', title: '会議 D', date: DateTime(2026, 3, 1), description: '予算'),
    ScheduleEvent(id: 'other', title: '会議 E', date: DateTime(2025, 12, 31)),
  ];
  final anchor = DateTime(2026, 10, 20);

  List<String> ids(PeriodUnit? unit, {String query = '', EventFilter filter = EventFilter.all}) =>
      filterScheduleEvents(events, unit: unit, anchor: anchor, query: query, filter: filter)
          .map((e) => e.id)
          .toList();

  test('period limits the search range', () {
    expect(ids(PeriodUnit.day, query: '会議'), ['day']);
    expect(ids(PeriodUnit.week, query: '会議'), ['day', 'week']);
    expect(ids(PeriodUnit.month, query: '会議'), ['month', 'day', 'week']);
    expect(ids(PeriodUnit.year, query: '会議'), ['year', 'month', 'day', 'week']);
    expect(ids(null, query: '会議'), ['other', 'year', 'month', 'day', 'week']);
  });

  test('results are sorted by date then time', () {
    expect(ids(PeriodUnit.day), ['dayEarly', 'day']);
  });

  test('query matches description and status filter still applies', () {
    expect(ids(null, query: '予算'), ['year']);
    expect(ids(PeriodUnit.week, filter: EventFilter.completed), ['week']);
    expect(ids(PeriodUnit.week, filter: EventFilter.pending), ['dayEarly', 'day']);
  });
}
