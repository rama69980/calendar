import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/schedule_event.dart';
import 'storage_service.dart';
import 'web_account_service.dart';

/// 予定を見られる社員 (管理者・承認済み社員)
class MemberInfo {
  final String email;
  final String displayName;
  final String? profileImage;
  final bool isAdmin;
  final bool isMe;

  const MemberInfo({
    required this.email,
    required this.displayName,
    this.profileImage,
    required this.isAdmin,
    required this.isMe,
  });

  factory MemberInfo.fromJson(Map<String, dynamic> json) => MemberInfo(
        email: json['email'] as String,
        displayName: json['displayName'] as String? ?? json['email'] as String,
        profileImage: json['profileImage'] as String?,
        isAdmin: json['admin'] as bool? ?? false,
        isMe: json['me'] as bool? ?? false,
      );
}

/// 検索結果の予定 1件。他の人の非公開予定はサーバーで「予定あり」に置き換えられている
class MemberSchedule {
  final String ownerEmail;
  final String ownerName;
  final bool mine;
  final String title;
  final String description;
  final DateTime date;
  final bool hasTime;
  final int hour;
  final int minute;
  final int colorValue;
  final bool completed;
  final bool isPrivate;

  const MemberSchedule({
    required this.ownerEmail,
    required this.ownerName,
    required this.mine,
    required this.title,
    required this.description,
    required this.date,
    required this.hasTime,
    required this.hour,
    required this.minute,
    required this.colorValue,
    required this.completed,
    required this.isPrivate,
  });

  factory MemberSchedule.fromJson(Map<String, dynamic> json) => MemberSchedule(
        ownerEmail: json['ownerEmail'] as String,
        ownerName: json['ownerName'] as String,
        mine: json['mine'] as bool? ?? false,
        title: json['title'] as String,
        description: json['description'] as String? ?? '',
        date: DateTime.parse(json['date'] as String),
        hasTime: json['hasTime'] as bool? ?? false,
        hour: json['hour'] as int? ?? 0,
        minute: json['minute'] as int? ?? 0,
        colorValue: (json['colorValue'] as int? ?? 0xFF94A3B8).toUnsigned(32),
        completed: json['completed'] as bool? ?? false,
        isPrivate: json['privateEvent'] as bool? ?? false,
      );

  /// 自分の予定 (端末内) も同じ形で並べるため
  factory MemberSchedule.fromLocal(ScheduleEvent e, {required String ownerEmail, required String ownerName}) =>
      MemberSchedule(
        ownerEmail: ownerEmail,
        ownerName: ownerName,
        mine: true,
        title: e.title,
        description: e.description,
        date: DateTime(e.date.year, e.date.month, e.date.day),
        hasTime: e.hasTime,
        hour: e.hour,
        minute: e.minute,
        colorValue: e.colorValue,
        completed: e.isCompleted,
        isPrivate: e.isPrivate,
      );

  int get sortKey => hasTime ? hour * 60 + minute : -1;
}

class MemberException implements Exception {
  final String message;
  final int? statusCode;
  MemberException(this.message, [this.statusCode]);
  @override
  String toString() => message;
}

/// 社員どうしで予定を見るためのサービス。
/// - calendarWEB アカウントでログイン中は、自分の予定を自動でサーバーへアップロードする
/// - 管理者・承認済み社員は、期間とメンバーを選んで他の社員の予定を検索できる
class MemberService {
  static final MemberService instance = MemberService._();
  MemberService._();

  static const Duration uploadDelay = Duration(seconds: 3);

  @visibleForTesting
  http.Client httpClient = http.Client();

  /// 予定を見られる社員一覧 (自分が社員でなければ空)
  final ValueNotifier<List<MemberInfo>> membersNotifier = ValueNotifier<List<MemberInfo>>(const []);
  List<MemberInfo> get members => membersNotifier.value;

  Timer? _uploadTimer;
  String? _lastUploadedPayload;
  bool _started = false;

  /// 社員登録用 URL (QR コード)。開くと「cal の社員です」にチェックが入った会員登録画面になる
  static String get registrationUrl => '${WebAccountService.webBaseUrl}/RegistrationPage?employee=1';

  bool get hasMemberAccess => WebAccountService.instance.account?.memberAccess ?? false;

  /// アプリ起動時に1回。予定の保存・ログイン状態の変化を監視して自動アップロードする
  void start() {
    if (_started) return;
    _started = true;
    StorageService.eventsRevision.addListener(scheduleUpload);
    WebAccountService.instance.accountNotifier.addListener(_onAccountChanged);
    _onAccountChanged();
  }

  // プロフィール更新のたびに通知が来るので、アカウントか権限が変わったときだけ動く
  void _onAccountChanged() {
    final account = WebAccountService.instance.account;
    if (account == null) {
      _uploadTimer?.cancel();
      _lastUploadedPayload = null;
      _lastEmail = null;
      _lastMemberAccess = false;
      membersNotifier.value = const [];
      return;
    }
    if (account.email != _lastEmail) {
      _lastEmail = account.email;
      _lastMemberAccess = account.memberAccess;
      _lastUploadedPayload = null; // 別アカウントかもしれないので必ず送り直す
      scheduleUpload();
      _loadMembers();
    } else if (account.memberAccess != _lastMemberAccess) {
      _lastMemberAccess = account.memberAccess; // 承認された / 外された
      _loadMembers();
    }
  }

  String? _lastEmail;
  bool _lastMemberAccess = false;

  /// 予定が変わったら少し待ってからまとめてアップロード
  void scheduleUpload() {
    if (!WebAccountService.instance.isSignedIn) return;
    _uploadTimer?.cancel();
    _uploadTimer = Timer(uploadDelay, () => uploadMySchedules());
  }

  // ---------------------------------------------------------------- members

  /// 社員一覧を更新 (社員でなければ空)。承認状態も最新にするためプロフィールも取り直す
  Future<List<MemberInfo>> refreshMembers() async {
    await WebAccountService.instance.refreshProfile();
    return _loadMembers();
  }

  Future<List<MemberInfo>> _loadMembers() async {
    if (!hasMemberAccess) {
      membersNotifier.value = const [];
      return members;
    }
    try {
      final data = await _send('GET', '/api/members') as List<dynamic>;
      membersNotifier.value = data.map((m) => MemberInfo.fromJson(m as Map<String, dynamic>)).toList();
    } on MemberException catch (e) {
      debugPrint('[MemberService] refreshMembers failed: $e');
    }
    return members;
  }

  /// 社員申請 (管理者の承認待ちになる)
  Future<void> requestEmployee() async {
    await _send('POST', '/api/members/request');
    await WebAccountService.instance.refreshProfile();
  }

  // ---------------------------------------------------------------- schedules

  /// 自分の予定 (削除済みを除く) をすべて送る。前回と同じ内容なら送らない
  Future<bool> uploadMySchedules() async {
    if (!WebAccountService.instance.isSignedIn) return false;

    final events = StorageService.loadEvents();
    final payload = jsonEncode({'schedules': events.map(toUploadJson).toList()});
    if (payload == _lastUploadedPayload) return true;

    try {
      await _send('PUT', '/api/schedules/mine', rawBody: payload);
      _lastUploadedPayload = payload;
      return true;
    } on MemberException catch (e) {
      debugPrint('[MemberService] upload failed: $e');
      return false;
    }
  }

  @visibleForTesting
  static Map<String, dynamic> toUploadJson(ScheduleEvent e) => {
        'clientId': e.id,
        'title': e.title,
        'description': e.description,
        'date': dateString(e.date),
        'hasTime': e.hasTime,
        'hour': e.hour,
        'minute': e.minute,
        // サーバー (Java int) は符号付き 32bit
        'colorValue': e.colorValue.toSigned(32),
        'completed': e.isCompleted,
        'privateEvent': e.isPrivate,
      };

  /// 期間 [from, to] の他の社員の予定 (サーバーにアップロード済みのもの)
  Future<List<MemberSchedule>> searchSchedules({
    required DateTime from,
    required DateTime to,
    required List<String> memberEmails,
  }) async {
    if (memberEmails.isEmpty) return [];
    final query = [
      'from=${dateString(from)}',
      'to=${dateString(to)}',
      ...memberEmails.map((m) => 'members=${Uri.encodeQueryComponent(m)}'),
    ].join('&');
    final data = await _send('GET', '/api/schedules?$query') as List<dynamic>;
    return data.map((j) => MemberSchedule.fromJson(j as Map<String, dynamic>)).toList();
  }

  // ---------------------------------------------------------------- http

  Future<dynamic> _send(String method, String path, {String? rawBody}) async {
    final token = StorageService.getWebAccountToken();
    if (token == null) throw MemberException('calendarWEB アカウントでログインしてください', 401);

    final request = http.Request(method, Uri.parse('${WebAccountService.apiBaseUrl}$path'))
      ..headers['Authorization'] = 'Bearer $token';
    if (rawBody != null) {
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      request.body = rawBody;
    }

    http.Response response;
    try {
      response = await http.Response.fromStream(
          await httpClient.send(request).timeout(const Duration(seconds: 15)));
    } catch (e) {
      throw MemberException('サーバーに接続できません');
    }

    final text = utf8.decode(response.bodyBytes);
    if (response.statusCode == 401) {
      await WebAccountService.instance.signOut(); // トークン切れ → 再ログインしてもらう
      throw MemberException('ログインの有効期限が切れました。もう一度ログインしてください', 401);
    }
    if (response.statusCode >= 400) {
      String message = 'エラーが発生しました (${response.statusCode})';
      try {
        message = (jsonDecode(text) as Map<String, dynamic>)['message'] as String? ?? message;
      } catch (_) {}
      throw MemberException(message, response.statusCode);
    }
    return text.isEmpty ? null : jsonDecode(text);
  }

  static String dateString(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
