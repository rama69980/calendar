import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:calendar/main.dart';
import 'package:calendar/services/storage_service.dart';

void main() {
  testWidgets('Calendar App smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    await initializeDateFormatting('ja_JP', null);

    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Verify title and main widgets are present
    expect(find.text('スケジュール＆カレンダー'), findsOneWidget);
    expect(find.text('予定を追加'), findsWidgets);
    expect(find.byIcon(Icons.calendar_month_rounded), findsOneWidget);
  });
}
