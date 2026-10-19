import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'pkce.dart';
import 'storage_service.dart';

/// calendarWEB アカウントのプロフィール (表示用)
class WebAccount {
  final String email;
  final String? nickname;
  final String? profileImage;

  const WebAccount({required this.email, this.nickname, this.profileImage});

  String get displayName =>
      (nickname != null && nickname!.trim().isNotEmpty) ? nickname! : email;

  /// プロフィール画像の URL (未設定なら null)
  String? get imageUrl => (profileImage == null || profileImage!.isEmpty)
      ? null
      : '${WebAccountService.apiBaseUrl}/uploads/${Uri.encodeComponent(profileImage!)}';

  factory WebAccount.fromJson(Map<String, dynamic> json) => WebAccount(
        email: json['email'] as String,
        nickname: json['usernickname'] as String?,
        profileImage: json['profileImage'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'email': email,
        'usernickname': nickname,
        'profileImage': profileImage,
      };
}

enum WebSignInResult { success, cancelled, timeout, failed }

/// calendarWEB アカウントでのログイン (ブラウザ連携)
///
/// 1. PKCE の verifier/challenge と、このPCだけで待ち受ける loopback サーバー (127.0.0.1:空きポート) を用意
/// 2. ブラウザで calendarWEB の /DesktopLogin を開く (Web 側でログイン済みなら「許可」を押すだけ)
/// 3. Web が 1回用コードを loopback に渡す → verifier と一緒にバックエンドへ送り、長期トークンを受け取る
class WebAccountService {
  static final WebAccountService instance = WebAccountService._();
  WebAccountService._();

  // ビルド時に --dart-define で変更可能 (配布版では本番の URL を指定する)
  static const String webBaseUrl =
      String.fromEnvironment('CALENDARWEB_URL', defaultValue: 'http://localhost:5173');
  static const String apiBaseUrl =
      String.fromEnvironment('CALENDARWEB_API_URL', defaultValue: 'http://localhost:8080');

  static const Duration signInTimeout = Duration(minutes: 5);

  /// テストで差し替え可能
  @visibleForTesting
  http.Client httpClient = http.Client();

  @visibleForTesting
  Future<bool> Function(Uri url) openBrowser =
      (url) => launchUrl(url, mode: LaunchMode.externalApplication);

  final ValueNotifier<WebAccount?> accountNotifier = ValueNotifier<WebAccount?>(null);

  WebAccount? get account => accountNotifier.value;
  bool get isSignedIn => accountNotifier.value != null;

  HttpServer? _loopbackServer;
  Completer<Uri?>? _callbackCompleter;

  /// 起動時: 保存済みの情報ですぐ表示し、裏でプロフィールを最新化 (トークン失効ならログアウト)
  Future<void> init() async {
    final token = StorageService.getWebAccountToken();
    final profileJson = StorageService.getWebAccountProfileJson();
    if (token == null) return;

    try {
      if (profileJson != null) {
        accountNotifier.value = WebAccount.fromJson(jsonDecode(profileJson) as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('[WebAccountService] Broken saved profile: $e');
    }

    await refreshProfile();
  }

  /// プロフィール再取得。トークンが無効ならログアウトする (通信エラー時は保存済み情報のまま)
  Future<void> refreshProfile() async {
    final token = StorageService.getWebAccountToken();
    if (token == null) return;

    try {
      final response = await httpClient.get(
        Uri.parse('$apiBaseUrl/api/auth/userinformation'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 401) {
        debugPrint('[WebAccountService] Token expired; signing out');
        await signOut();
        return;
      }
      if (response.statusCode == 200) {
        final account = WebAccount.fromJson(jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>);
        accountNotifier.value = account;
        await StorageService.setWebAccountProfileJson(jsonEncode(account.toJson()));
      }
    } catch (e) {
      debugPrint('[WebAccountService] Profile refresh failed (offline?): $e');
    }
  }

  /// ブラウザ連携ログイン
  Future<WebSignInResult> signIn() async {
    if (_loopbackServer != null) return WebSignInResult.failed; // 既にログイン処理中

    final pkce = Pkce.generate();
    final state = Pkce.randomUrlSafe(16);

    try {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _loopbackServer = server;
      final redirectUri = 'http://127.0.0.1:${server.port}/callback';
      final completer = Completer<Uri?>();
      _callbackCompleter = completer;

      server.listen((request) => _handleLoopbackRequest(request, completer));

      final loginUrl = Uri.parse('$webBaseUrl/DesktopLogin').replace(queryParameters: {
        'redirect_uri': redirectUri,
        'code_challenge': pkce.challenge,
        'code_challenge_method': 'S256',
        'state': state,
      });
      if (!await openBrowser(loginUrl)) {
        debugPrint('[WebAccountService] Could not open browser');
        return WebSignInResult.failed;
      }

      final callback = await completer.future.timeout(signInTimeout, onTimeout: () => null);
      if (callback == null) {
        return completer.isCompleted ? WebSignInResult.cancelled : WebSignInResult.timeout;
      }

      final params = callback.queryParameters;
      if (params['state'] != state) {
        debugPrint('[WebAccountService] State mismatch');
        return WebSignInResult.failed;
      }
      if (params['error'] != null) return WebSignInResult.cancelled;

      final code = params['code'];
      if (code == null) return WebSignInResult.failed;

      return await _exchangeCode(code, pkce.verifier, redirectUri);
    } catch (e) {
      debugPrint('[WebAccountService] Sign-in error: $e');
      return WebSignInResult.failed;
    } finally {
      await _closeLoopback();
    }
  }

  /// ログイン待機をやめる (設定画面のキャンセルボタン)
  void cancelSignIn() {
    final completer = _callbackCompleter;
    if (completer != null && !completer.isCompleted) completer.complete(null);
  }

  Future<void> signOut() async {
    accountNotifier.value = null;
    await StorageService.clearWebAccount();
  }

  Future<WebSignInResult> _exchangeCode(String code, String verifier, String redirectUri) async {
    final response = await httpClient.post(
      Uri.parse('$apiBaseUrl/api/auth/desktop/token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'code': code, 'codeVerifier': verifier, 'redirectUri': redirectUri}),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      debugPrint('[WebAccountService] Token exchange failed: ${response.statusCode} ${response.body}');
      return WebSignInResult.failed;
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final token = data['token'] as String;
    final account = WebAccount(email: data['email'] as String);

    await StorageService.setWebAccount(token, jsonEncode(account.toJson()));
    accountNotifier.value = account;
    await refreshProfile(); // ニックネーム・プロフィール画像
    return WebSignInResult.success;
  }

  void _handleLoopbackRequest(HttpRequest request, Completer<Uri?> completer) {
    if (request.uri.path != '/callback') {
      request.response
        ..statusCode = HttpStatus.notFound
        ..close();
      return;
    }

    final cancelled = request.uri.queryParameters.containsKey('error');
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.html
      ..write(_callbackPage(cancelled))
      ..close();

    if (!completer.isCompleted) completer.complete(request.uri);
  }

  Future<void> _closeLoopback() async {
    _callbackCompleter = null;
    final server = _loopbackServer;
    _loopbackServer = null;
    await server?.close(force: true);
  }

  static String _callbackPage(bool cancelled) {
    final message = cancelled
        ? 'ログインをキャンセルしました。'
        : 'ログインしました。calendar アプリに戻ってください。';
    return '<!doctype html><html lang="ja"><head><meta charset="utf-8"><title>calendar</title></head>'
        '<body style="font-family:sans-serif;background:#0f172a;color:#e2e8f0;display:flex;'
        'align-items:center;justify-content:center;height:100vh;margin:0">'
        '<p>$message このタブは閉じてかまいません。</p></body></html>';
  }
}
