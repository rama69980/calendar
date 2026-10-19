import 'dart:convert';
import 'package:calendar/models/schedule_event.dart';
import 'package:calendar/services/member_service.dart';
import 'package:calendar/services/storage_service.dart';
import 'package:calendar/services/web_account_service.dart';
import 'package:calendar/widgets/schedule_search_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  http.Response json(Object body) => http.Response.bytes(utf8.encode(jsonEncode(body)), 200,
      headers: {'content-type': 'application/json; charset=utf-8'});

  testWidgets('member schedules are listed and summary shows who is free', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    final profile = {'email': 'me@test.com', 'usernickname': '私', 'memberAccess': true, 'employeeStatus': 'APPROVED'};
    await StorageService.setWebAccount('token', jsonEncode(profile));
    WebAccountService.instance.httpClient = MockClient((_) async => json(profile));
    await WebAccountService.instance.init();

    // 自分の予定 (端末内): 検索期間 (2026/10/18〜24 の週) に 1件
    await StorageService.saveEvents([
      ScheduleEvent(id: 'mine', title: '自分の打ち合わせ', date: DateTime(2026, 10, 21), hour: 13),
    ]);

    String? requestedQuery;
    MemberService.instance.httpClient = MockClient((request) async {
      if (request.url.path == '/api/members') {
        return json([
          {'email': 'me@test.com', 'displayName': '私', 'admin': false, 'me': true},
          {'email': 'boss@test.com', 'displayName': '部長', 'admin': true, 'me': false},
          {'email': 'free@test.com', 'displayName': '暇な人', 'admin': false, 'me': false},
        ]);
      }
      requestedQuery = request.url.query;
      return json([
        {
          'ownerEmail': 'boss@test.com', 'ownerName': '部長', 'mine': false, 'title': '予定あり',
          'description': '', 'date': '2026-10-22', 'hasTime': true, 'hour': 10, 'minute': 0,
          'colorValue': 0xFF94A3B8.toSigned(32), 'completed': false, 'privateEvent': true,
        },
      ]);
    });
    await MemberService.instance.refreshMembers();

    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ScheduleSearchDialog(initialDate: DateTime(2026, 10, 21))),
      ));
      await tester.pump();
    });

    // 週表示 + 自分の予定
    expect(find.text('2026/10/18 〜 10/24'), findsOneWidget);
    expect(find.text('自分の打ち合わせ'), findsOneWidget);
    expect(find.text('自分: 1件'), findsOneWidget);

    // 部長と暇な人を選ぶ → サーバーに 2人分の検索が飛ぶ
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilterChip, '部長'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilterChip, '暇な人'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    expect(requestedQuery, contains('from=2026-10-18'));
    expect(requestedQuery, contains('to=2026-10-24'));
    expect(requestedQuery, contains('members=boss%40test.com'));
    expect(requestedQuery, contains('members=free%40test.com'));
    expect(find.text('予定あり'), findsOneWidget); // 部長の非公開予定
    expect(find.text('部長: 1件'), findsOneWidget);
    expect(find.text('暇な人: 予定なし'), findsOneWidget);

    // 月に切り替え
    await tester.runAsync(() async {
      await tester.tap(find.text('月'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });
    expect(find.text('2026年10月'), findsOneWidget);
    expect(requestedQuery, contains('to=2026-10-31'));
  });
}
