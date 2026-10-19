import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:calendar/models/schedule_event.dart';
import 'package:calendar/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScheduleEvent Model Tests', () {
    test('JSON serialization & deserialization', () {
      final event = ScheduleEvent(
        id: 'test-id-123',
        title: 'ミーティング',
        description: 'プロジェクトキックオフ会議',
        date: DateTime(2026, 8, 20),
        hasTime: true,
        hour: 14,
        minute: 30,
        colorValue: 0xFF10B981,
        isCompleted: false,
        enableNotification: true,
        notificationOffsetMinutes: 10,
        isNotified: false,
      );

      final json = event.toJson();
      final fromJson = ScheduleEvent.fromJson(json);

      expect(fromJson.id, 'test-id-123');
      expect(fromJson.title, 'ミーティング');
      expect(fromJson.description, 'プロジェクトキックオフ会議');
      expect(fromJson.date.year, 2026);
      expect(fromJson.date.month, 8);
      expect(fromJson.date.day, 20);
      expect(fromJson.hasTime, true);
      expect(fromJson.hour, 14);
      expect(fromJson.minute, 30);
      expect(fromJson.colorValue, 0xFF10B981);
      expect(fromJson.isCompleted, false);
      expect(fromJson.enableNotification, true);
      expect(fromJson.notificationOffsetMinutes, 10);
      expect(fromJson.isNotified, false);
    });

    test('Google sync fields serialization & deserialization', () {
      final event = ScheduleEvent(
        id: 'g-1',
        title: 'Google Event Test',
        date: DateTime(2026, 8, 20),
        googleEventId: 'gcal_event_999',
        etag: '"etag_value"',
        syncStatus: 'synced',
        isDeletedLocally: false,
      );

      expect(event.isGoogleSynced, true);

      final json = event.toJson();
      final fromJson = ScheduleEvent.fromJson(json);

      expect(fromJson.googleEventId, 'gcal_event_999');
      expect(fromJson.etag, '"etag_value"');
      expect(fromJson.syncStatus, 'synced');
      expect(fromJson.isDeletedLocally, false);
      expect(fromJson.isGoogleSynced, true);
    });

    test('notificationDateTime calculation', () {
      final event = ScheduleEvent(
        id: 'test-2',
        title: '歯医者',
        date: DateTime(2026, 8, 20),
        hasTime: true,
        hour: 15,
        minute: 0,
        notificationOffsetMinutes: 30, // 30分前
      );

      final notifyTime = event.notificationDateTime;
      expect(notifyTime, DateTime(2026, 8, 20, 14, 30));
    });

    test('copyWith works correctly', () {
      final event = ScheduleEvent(
        id: 'test-3',
        title: '既存のタイトル',
        date: DateTime(2026, 8, 20),
        isCompleted: false,
      );

      final updated = event.copyWith(
        title: '更新後のタイトル',
        isCompleted: true,
        googleEventId: 'new_gid',
      );

      expect(updated.id, 'test-3');
      expect(updated.title, '更新後のタイトル');
      expect(updated.isCompleted, true);
      expect(updated.googleEventId, 'new_gid');
    });
  });

  group('StorageService Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.init();
    });

    test('Add, Load, ToggleComplete and Delete Events', () async {
      final event = ScheduleEvent(
        id: 'e1',
        title: 'テスト予定 1',
        date: DateTime(2026, 8, 20),
        colorValue: 0xFFEF4444,
      );

      await StorageService.addEvent(event);
      var events = StorageService.loadEvents();
      expect(events.length, 1);
      expect(events.first.title, 'テスト予定 1');
      expect(events.first.isCompleted, false);

      // Toggle Complete
      await StorageService.toggleComplete('e1');
      events = StorageService.loadEvents();
      expect(events.first.isCompleted, true);

      // Delete Event (local-only)
      await StorageService.deleteEvent('e1');
      events = StorageService.loadEvents();
      expect(events.isEmpty, true);
    });

    test('Google synced event deletion creates tombstone', () async {
      final gEvent = ScheduleEvent(
        id: 'g-event-1',
        title: 'Google Synced Event',
        date: DateTime(2026, 8, 20),
        googleEventId: 'gid_123',
        syncStatus: 'synced',
      );

      await StorageService.addEvent(gEvent);

      // Visible events should show it
      expect(StorageService.loadEvents().length, 1);

      // Delete creates tombstone
      await StorageService.deleteEvent('g-event-1');

      // Normal load excludes tombstone
      expect(StorageService.loadEvents().length, 0);

      // IncludeDeleted load still has it for remote sync
      final allRaw = StorageService.loadEvents(includeDeleted: true);
      expect(allRaw.length, 1);
      expect(allRaw.first.isDeletedLocally, true);
      expect(allRaw.first.syncStatus, 'pendingDelete');

      // Purge permanently
      await StorageService.purgeEvent('g-event-1');
      expect(StorageService.loadEvents(includeDeleted: true).isEmpty, true);
    });

    test('Settings get and set', () async {
      expect(StorageService.getAutoStart(), true);
      await StorageService.setAutoStart(false);
      expect(StorageService.getAutoStart(), false);

      expect(StorageService.getMinimizeToTray(), true);
      await StorageService.setMinimizeToTray(false);
      expect(StorageService.getMinimizeToTray(), false);

      expect(StorageService.getGoogleAutoSync(), true);
      await StorageService.setGoogleAutoSync(false);
      expect(StorageService.getGoogleAutoSync(), false);
    });
  });
}
