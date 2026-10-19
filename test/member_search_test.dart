import 'dart:convert';
import 'package:calendar/models/schedule_event.dart';
import 'package:calendar/services/member_service.dart';
import 'package:calendar/services/storage_service.dart';
import 'package:calendar/services/web_account_service.dart';
import 'package:calendar/utils/search_period.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SearchPeriod', () {
    final anchor = DateTime(2026, 10, 21, 15, 30); // 水曜

    test('year / month / week (Sunday start) / day ranges', () {
      final year = SearchPeriod.of(PeriodUnit.year, anchor);
      expect([year.from, year.to], [DateTime(2026, 1, 1), DateTime(2026, 12, 31)]);

      final month = SearchPeriod.of(PeriodUnit.month, anchor);
      expect([month.from, month.to], [DateTime(2026, 10, 1), DateTime(2026, 10, 31)]);

      final week = SearchPeriod.of(PeriodUnit.week, anchor);
      expect([week.from, week.to], [DateTime(2026, 10, 18), DateTime(2026, 10, 24)]);
      expect(week.from.weekday, DateTime.sunday);

      final day = SearchPeriod.of(PeriodUnit.day, anchor);
      expect([day.from, day.to], [DateTime(2026, 10, 21), DateTime(2026, 10, 21)]);
    });

    test('week starting on Sunday stays in the same week', () {
      final sunday = SearchPeriod.of(PeriodUnit.week, DateTime(2026, 10, 18));
      expect(sunday.from, DateTime(2026, 10, 18));
    });

    test('shift moves across month and year boundaries', () {
      expect(SearchPeriod.of(PeriodUnit.month, DateTime(2026, 12, 5)).shift(1).from, DateTime(2027, 1, 1));
      expect(SearchPeriod.of(PeriodUnit.month, DateTime(2026, 3, 31)).shift(-1).to, DateTime(2026, 2, 28));
      expect(SearchPeriod.of(PeriodUnit.week, DateTime(2026, 12, 30)).shift(1).from, DateTime(2027, 1, 3));
      expect(SearchPeriod.of(PeriodUnit.day, DateTime(2026, 12, 31)).shift(1).from, DateTime(2027, 1, 1));
      expect(SearchPeriod.of(PeriodUnit.year, anchor).shift(-1).label, '2025年');
    });

    test('contains ignores time of day', () {
      final week = SearchPeriod.of(PeriodUnit.week, anchor);
      expect(week.contains(DateTime(2026, 10, 24, 23, 59)), isTrue);
      expect(week.contains(DateTime(2026, 10, 25)), isFalse);
    });
  });

  group('schedule sharing format', () {
    test('private flag survives local save/load', () {
      final e = ScheduleEvent(id: '1', title: 't', date: DateTime(2026, 10, 21), isPrivate: true);
      final restored = ScheduleEvent.fromJson(jsonDecode(jsonEncode(e.toJson())) as Map<String, dynamic>);
      expect(restored.isPrivate, isTrue);
      expect(ScheduleEvent.fromJson({'id': '2', 'title': 'old', 'date': '2026-10-21T00:00:00.000'}).isPrivate, isFalse);
    });

    test('colors are sent as signed 32-bit and read back unsigned', () {
      final e = ScheduleEvent(id: '1', title: 't', date: DateTime(2026, 10, 21), colorValue: 0xFF3B82F6);
      final json = MemberService.toUploadJson(e);
      expect(json['colorValue'], 0xFF3B82F6.toSigned(32));
      expect(json['colorValue'], lessThan(0));
      expect(json['date'], '2026-10-21');

      final back = MemberSchedule.fromJson({
        'ownerEmail': 'a@b.c', 'ownerName': 'A', 'title': 't', 'date': '2026-10-21',
        'colorValue': json['colorValue'], 'privateEvent': true,
      });
      expect(back.colorValue, 0xFF3B82F6);
      expect(back.isPrivate, isTrue);
    });
  });

  group('MemberService', () {
    final service = MemberService.instance;
    final account = WebAccountService.instance;

    Future<void> signIn({required bool memberAccess}) async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.init();
      final profile = jsonEncode({'email': 'me@test.com', 'memberAccess': memberAccess, 'employeeStatus': memberAccess ? 'APPROVED' : 'PENDING'});
      await StorageService.setWebAccount('token', profile);
      account.httpClient = MockClient((request) async => http.Response(profile, 200,
          headers: {'content-type': 'application/json; charset=utf-8'}));
      await account.init();
    }

    test('non-members get no member list and no request is made', () async {
      await signIn(memberAccess: false);
      var called = false;
      service.httpClient = MockClient((request) async {
        called = true;
        return http.Response('[]', 200);
      });

      expect(await service.refreshMembers(), isEmpty);
      expect(called, isFalse);
      expect(account.account!.employeeStatus, 'PENDING');
    });

    test('members are loaded for approved employees', () async {
      await signIn(memberAccess: true);
      service.httpClient = MockClient((request) async {
        expect(request.url.path, '/api/members');
        expect(request.headers['Authorization'], 'Bearer token');
        return http.Response.bytes(
            utf8.encode(jsonEncode([
              {'email': 'me@test.com', 'displayName': '私', 'admin': false, 'me': true},
              {'email': 'boss@test.com', 'displayName': '管理者', 'admin': true, 'me': false},
            ])),
            200);
      });

      final members = await service.refreshMembers();
      expect(members.map((m) => m.displayName), ['私', '管理者']);
      expect(members.last.isAdmin, isTrue);
    });

    test('upload sends all local events once and skips unchanged payloads', () async {
      await signIn(memberAccess: false);
      await StorageService.saveEvents([
        ScheduleEvent(id: 'a', title: '会議', date: DateTime(2026, 10, 21), isPrivate: true),
      ]);
      final bodies = <String>[];
      service.httpClient = MockClient((request) async {
        bodies.add(request.body);
        return http.Response('{"count":1}', 200);
      });

      expect(await service.uploadMySchedules(), isTrue);
      expect(await service.uploadMySchedules(), isTrue);
      expect(bodies, hasLength(1));
      final sent = jsonDecode(bodies.single) as Map<String, dynamic>;
      expect((sent['schedules'] as List).single['privateEvent'], isTrue);
    });

    test('server error message is surfaced', () async {
      await signIn(memberAccess: true);
      service.httpClient = MockClient((request) async => http.Response.bytes(
          utf8.encode('{"message":"社員として承認されたメンバーの予定だけ見られます"}'), 403));

      expect(
        () => service.searchSchedules(from: DateTime(2026), to: DateTime(2026), memberEmails: ['x@test.com']),
        throwsA(isA<MemberException>().having((e) => e.message, 'message', contains('承認'))),
      );
    });
  });
}
