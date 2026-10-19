import 'package:flutter/material.dart';

class ScheduleEvent {
  final String id;
  String title;
  String description;
  DateTime date; // YYYY-MM-DD (日付基準)
  bool hasTime; // 時間指定フラグ
  int hour; // 0-23
  int minute; // 0-59
  int colorValue; // 32-bit ARGB カラー値
  bool isCompleted; // 完了チェック
  bool enableNotification; // 通知有効化フラグ
  int notificationOffsetMinutes; // 0: 時間ちょうど, 10: 10分前, 30: 30分前, 60: 1時間前, 1440: 1日前
  bool isNotified; // 通知送信済みフラグ
  bool isPrivate; // 非公開: チームのメンバーには「予定あり」と時間だけ見せる
  final DateTime createdAt;
  DateTime updatedAt;

  // Google Calendar Integration
  String? googleEventId;
  String? etag;
  String syncStatus; // 'synced', 'pendingUpload', 'pendingUpdate', 'pendingDelete', 'localOnly'
  bool isDeletedLocally;

  ScheduleEvent({
    required this.id,
    required this.title,
    this.description = '',
    required this.date,
    this.hasTime = false,
    this.hour = 9,
    this.minute = 0,
    this.colorValue = 0xFF3B82F6, // デフォルトブルー
    this.isCompleted = false,
    this.enableNotification = true,
    this.notificationOffsetMinutes = 0,
    this.isNotified = false,
    this.isPrivate = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.googleEventId,
    this.etag,
    this.syncStatus = 'localOnly',
    this.isDeletedLocally = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Color get color => Color(colorValue);

  TimeOfDay get timeOfDay => TimeOfDay(hour: hour, minute: minute);

  bool get isGoogleSynced => googleEventId != null && googleEventId!.isNotEmpty;

  DateTime get scheduledDateTime {
    if (hasTime) {
      return DateTime(date.year, date.month, date.day, hour, minute);
    } else {
      // 終日予定の場合は該当日の09:00基準
      return DateTime(date.year, date.month, date.day, 9, 0);
    }
  }

  DateTime get notificationDateTime {
    return scheduledDateTime.subtract(Duration(minutes: notificationOffsetMinutes));
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': date.toIso8601String(),
      'hasTime': hasTime,
      'hour': hour,
      'minute': minute,
      'colorValue': colorValue,
      'isCompleted': isCompleted,
      'enableNotification': enableNotification,
      'notificationOffsetMinutes': notificationOffsetMinutes,
      'isNotified': isNotified,
      'isPrivate': isPrivate,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'googleEventId': googleEventId,
      'etag': etag,
      'syncStatus': syncStatus,
      'isDeletedLocally': isDeletedLocally,
    };
  }

  factory ScheduleEvent.fromJson(Map<String, dynamic> json) {
    return ScheduleEvent(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      date: DateTime.parse(json['date'] as String),
      hasTime: json['hasTime'] as bool? ?? false,
      hour: json['hour'] as int? ?? 9,
      minute: json['minute'] as int? ?? 0,
      colorValue: json['colorValue'] as int? ?? 0xFF3B82F6,
      isCompleted: json['isCompleted'] as bool? ?? false,
      enableNotification: json['enableNotification'] as bool? ?? true,
      notificationOffsetMinutes: json['notificationOffsetMinutes'] as int? ?? 0,
      isNotified: json['isNotified'] as bool? ?? false,
      isPrivate: json['isPrivate'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
      googleEventId: json['googleEventId'] as String?,
      etag: json['etag'] as String?,
      syncStatus: json['syncStatus'] as String? ?? 'localOnly',
      isDeletedLocally: json['isDeletedLocally'] as bool? ?? false,
    );
  }

  ScheduleEvent copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? date,
    bool? hasTime,
    int? hour,
    int? minute,
    int? colorValue,
    bool? isCompleted,
    bool? enableNotification,
    int? notificationOffsetMinutes,
    bool? isNotified,
    bool? isPrivate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? googleEventId,
    String? etag,
    String? syncStatus,
    bool? isDeletedLocally,
  }) {
    return ScheduleEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      hasTime: hasTime ?? this.hasTime,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      colorValue: colorValue ?? this.colorValue,
      isCompleted: isCompleted ?? this.isCompleted,
      enableNotification: enableNotification ?? this.enableNotification,
      notificationOffsetMinutes:
          notificationOffsetMinutes ?? this.notificationOffsetMinutes,
      isNotified: isNotified ?? this.isNotified,
      isPrivate: isPrivate ?? this.isPrivate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      googleEventId: googleEventId ?? this.googleEventId,
      etag: etag ?? this.etag,
      syncStatus: syncStatus ?? this.syncStatus,
      isDeletedLocally: isDeletedLocally ?? this.isDeletedLocally,
    );
  }
}
