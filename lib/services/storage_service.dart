import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/schedule_event.dart';

class StorageService {
  static const String _eventsKey = 'schedule_events';
  static const String _autoStartKey = 'setting_auto_start';
  static const String _minimizeToTrayKey = 'setting_minimize_to_tray';
  static const String _darkModeKey = 'setting_dark_mode';

  // Google Calendar Keys
  static const String _googleAuthCredentialsKey = 'google_auth_credentials';
  static const String _googleUserEmailKey = 'google_user_email';
  static const String _googleUserNameKey = 'google_user_name';
  static const String _googleUserPhotoUrlKey = 'google_user_photo_url';
  static const String _googleLastSyncTimeKey = 'google_last_sync_time';
  static const String _googleAutoSyncKey = 'setting_google_auto_sync';

  // calendarWEB Account Keys
  static const String _webAccountTokenKey = 'web_account_token';
  static const String _webAccountProfileKey = 'web_account_profile';

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static SharedPreferences get prefs {
    if (_prefs == null) {
      throw StateError('StorageService must be initialized before use.');
    }
    return _prefs!;
  }

  // Event CRUD
  static List<ScheduleEvent> loadEvents({bool includeDeleted = false}) {
    final jsonString = prefs.getString(_eventsKey);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> decoded = jsonDecode(jsonString);
      final events = decoded
          .map((item) => ScheduleEvent.fromJson(item as Map<String, dynamic>))
          .toList();

      if (!includeDeleted) {
        return events.where((e) => !e.isDeletedLocally).toList();
      }
      return events;
    } catch (e) {
      debugPrint('[StorageService] Error loading events: $e');
      return [];
    }
  }

  static Future<void> saveEvents(List<ScheduleEvent> events) async {
    final List<Map<String, dynamic>> jsonList =
        events.map((e) => e.toJson()).toList();
    final jsonString = jsonEncode(jsonList);
    await prefs.setString(_eventsKey, jsonString);
  }

  static Future<void> addEvent(ScheduleEvent event) async {
    final events = loadEvents(includeDeleted: true);
    events.add(event);
    await saveEvents(events);
  }

  static Future<void> updateEvent(ScheduleEvent event) async {
    final events = loadEvents(includeDeleted: true);
    final index = events.indexWhere((e) => e.id == event.id);
    if (index != -1) {
      events[index] = event;
      await saveEvents(events);
    }
  }

  static Future<void> deleteEvent(String id) async {
    final events = loadEvents(includeDeleted: true);
    final index = events.indexWhere((e) => e.id == id);
    if (index != -1) {
      final event = events[index];
      if (event.isGoogleSynced) {
        // Google カレンダーと同期されている予定はサーバー側削除のため論理削除 (isDeletedLocally) としてマーク
        events[index] = event.copyWith(
          isDeletedLocally: true,
          syncStatus: 'pendingDelete',
        );
      } else {
        // ローカル専用の予定は即時削除
        events.removeAt(index);
      }
      await saveEvents(events);
    }
  }

  static Future<void> purgeEvent(String id) async {
    final events = loadEvents(includeDeleted: true);
    events.removeWhere((e) => e.id == id);
    await saveEvents(events);
  }

  static Future<ScheduleEvent?> toggleComplete(String id) async {
    final events = loadEvents(includeDeleted: true);
    final index = events.indexWhere((e) => e.id == id);
    if (index != -1) {
      final updated = events[index].copyWith(
        isCompleted: !events[index].isCompleted,
        syncStatus: events[index].isGoogleSynced ? 'pendingUpdate' : events[index].syncStatus,
      );
      events[index] = updated;
      await saveEvents(events);
      return updated;
    }
    return null;
  }

  static Future<void> markNotified(String id) async {
    final events = loadEvents(includeDeleted: true);
    final index = events.indexWhere((e) => e.id == id);
    if (index != -1) {
      events[index] = events[index].copyWith(isNotified: true);
      await saveEvents(events);
    }
  }

  // Google Auth & Sync Preferences
  static String? getGoogleAuthJson() {
    return prefs.getString(_googleAuthCredentialsKey);
  }

  static Future<void> setGoogleAuthJson(String? jsonString) async {
    if (jsonString == null) {
      await prefs.remove(_googleAuthCredentialsKey);
    } else {
      await prefs.setString(_googleAuthCredentialsKey, jsonString);
    }
  }

  static String? getGoogleUserEmail() {
    return prefs.getString(_googleUserEmailKey);
  }

  static Future<void> setGoogleUserEmail(String? email) async {
    if (email == null) {
      await prefs.remove(_googleUserEmailKey);
    } else {
      await prefs.setString(_googleUserEmailKey, email);
    }
  }

  static String? getGoogleUserName() {
    return prefs.getString(_googleUserNameKey);
  }

  static Future<void> setGoogleUserName(String? name) async {
    if (name == null) {
      await prefs.remove(_googleUserNameKey);
    } else {
      await prefs.setString(_googleUserNameKey, name);
    }
  }

  static String? getGoogleUserPhotoUrl() {
    return prefs.getString(_googleUserPhotoUrlKey);
  }

  static Future<void> setGoogleUserPhotoUrl(String? url) async {
    if (url == null) {
      await prefs.remove(_googleUserPhotoUrlKey);
    } else {
      await prefs.setString(_googleUserPhotoUrlKey, url);
    }
  }

  static DateTime? getGoogleLastSyncTime() {
    final str = prefs.getString(_googleLastSyncTimeKey);
    if (str != null) {
      return DateTime.tryParse(str);
    }
    return null;
  }

  static Future<void> setGoogleLastSyncTime(DateTime time) async {
    await prefs.setString(_googleLastSyncTimeKey, time.toIso8601String());
  }

  static bool getGoogleAutoSync() {
    return prefs.getBool(_googleAutoSyncKey) ?? true;
  }

  static Future<void> setGoogleAutoSync(bool value) async {
    await prefs.setBool(_googleAutoSyncKey, value);
  }

  static Future<void> clearGoogleAuth() async {
    await prefs.remove(_googleAuthCredentialsKey);
    await prefs.remove(_googleUserEmailKey);
    await prefs.remove(_googleUserNameKey);
    await prefs.remove(_googleUserPhotoUrlKey);
    await prefs.remove(_googleLastSyncTimeKey);
  }

  // calendarWEB Account (トークン + 表示用プロフィール JSON)
  static String? getWebAccountToken() => prefs.getString(_webAccountTokenKey);

  static String? getWebAccountProfileJson() => prefs.getString(_webAccountProfileKey);

  static Future<void> setWebAccount(String token, String profileJson) async {
    await prefs.setString(_webAccountTokenKey, token);
    await prefs.setString(_webAccountProfileKey, profileJson);
  }

  static Future<void> setWebAccountProfileJson(String profileJson) async {
    await prefs.setString(_webAccountProfileKey, profileJson);
  }

  static Future<void> clearWebAccount() async {
    await prefs.remove(_webAccountTokenKey);
    await prefs.remove(_webAccountProfileKey);
  }

  // General Settings
  static bool getAutoStart() {
    return prefs.getBool(_autoStartKey) ?? true;
  }

  static Future<void> setAutoStart(bool value) async {
    await prefs.setBool(_autoStartKey, value);
  }

  static bool getMinimizeToTray() {
    return prefs.getBool(_minimizeToTrayKey) ?? true;
  }

  static Future<void> setMinimizeToTray(bool value) async {
    await prefs.setBool(_minimizeToTrayKey, value);
  }

  static bool getDarkMode() {
    return prefs.getBool(_darkModeKey) ?? false;
  }

  static Future<void> setDarkMode(bool value) async {
    await prefs.setBool(_darkModeKey, value);
  }
}
