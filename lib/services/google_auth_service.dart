import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:googleapis/calendar/v3.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'storage_service.dart';

class GoogleAuthService {
  static final GoogleAuthService instance = GoogleAuthService._();
  GoogleAuthService._();

  // ビルド時に --dart-define(-from-file) で注入する (README / docs/GOOGLE_CALENDAR_MANUAL.md 参照)
  static const String _clientId = String.fromEnvironment('GOOGLE_CLIENT_ID');
  static const String _clientSecret = String.fromEnvironment('GOOGLE_CLIENT_SECRET');

  /// OAuth クライアント情報がビルドに含まれているか
  static bool get isConfigured => _clientId.isNotEmpty && _clientSecret.isNotEmpty;

  static final ClientId _clientIdentifier = ClientId(_clientId, _clientSecret);

  // 予定の読み書きだけ (カレンダー自体の作成・共有・削除の権限は要求しない)
  static const List<String> _scopes = [
    CalendarApi.calendarEventsScope,
    'https://www.googleapis.com/auth/userinfo.email',
    'https://www.googleapis.com/auth/userinfo.profile',
  ];

  AutoRefreshingAuthClient? _authenticatedClient;
  bool _isInitializing = false;

  final ValueNotifier<bool> isSignedInNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String?> userEmailNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<String?> userNameNotifier = ValueNotifier<String?>(null);

  bool get isSignedIn => _authenticatedClient != null;
  String? get userEmail => userEmailNotifier.value;
  String? get userName => userNameNotifier.value;
  AutoRefreshingAuthClient? get client => _authenticatedClient;

  /// アプリ起動時に保存済みトークンで自動ログインを試行
  Future<bool> init() async {
    if (_isInitializing) return isSignedIn;
    _isInitializing = true;

    try {
      final savedJson = StorageService.getGoogleAuthJson();
      final savedEmail = StorageService.getGoogleUserEmail();
      final savedName = StorageService.getGoogleUserName();

      userEmailNotifier.value = savedEmail;
      userNameNotifier.value = savedName;

      if (!isConfigured) {
        debugPrint('[GoogleAuthService] OAuth client is not configured; skipping auto-login');
      } else if (savedJson != null && savedJson.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(savedJson);

        // 別の (削除済みなど) OAuth クライアントで発行されたトークンは使えないので破棄して再ログインさせる
        if (data['clientId'] != _clientId) {
          debugPrint('[GoogleAuthService] Saved token belongs to another OAuth client; signing out');
          await signOut();
          return false;
        }

        final accessTokenData = data['accessToken'] as Map<String, dynamic>;

        final credentials = AccessCredentials(
          AccessToken(
            accessTokenData['type'] as String? ?? 'Bearer',
            accessTokenData['data'] as String,
            DateTime.parse(accessTokenData['expiry'] as String).toUtc(),
          ),
          data['refreshToken'] as String?,
          (data['scopes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
              _scopes,
          idToken: data['idToken'] as String?,
        );

        final authClient = autoRefreshingClient(
          _clientIdentifier,
          credentials,
          http.Client(),
        );

        // トークン更新時の自動保存リスナー登録
        authClient.credentialUpdates.listen((updatedCredentials) {
          _saveCredentials(updatedCredentials);
        });

        _authenticatedClient = authClient;
        isSignedInNotifier.value = true;

        // 最新のプロフィール情報をバックグラウンド更新
        _fetchAndSaveUserProfile(authClient);
        debugPrint('[GoogleAuthService] Auto-login succeeded: $savedEmail');
        return true;
      }
    } catch (e) {
      debugPrint('[GoogleAuthService] Auto-login error: $e');
      await signOut();
    } finally {
      _isInitializing = false;
    }

    isSignedInNotifier.value = false;
    return false;
  }

  /// ブラウザ OAuth 2.0 Loopback を通じた Google ログイン
  Future<bool> signIn() async {
    if (!isConfigured) {
      debugPrint('[GoogleAuthService] GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET are not set');
      return false;
    }
    try {
      debugPrint('[GoogleAuthService] Starting OAuth 2.0 Loopback flow...');

      final authClient = await clientViaUserConsent(
        _clientIdentifier,
        _scopes,
        (url) async {
          debugPrint('[GoogleAuthService] Opening browser with URL: $url');
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            throw Exception('Could not launch Google authentication browser');
          }
        },
      );

      _authenticatedClient = authClient;
      await _saveCredentials(authClient.credentials);

      authClient.credentialUpdates.listen((updatedCredentials) {
        _saveCredentials(updatedCredentials);
      });

      // ユーザーメールおよびプロフィール情報の取得
      await _fetchAndSaveUserProfile(authClient);

      isSignedInNotifier.value = true;
      debugPrint('[GoogleAuthService] Sign-in successful: ${userEmailNotifier.value}');
      return true;
    } catch (e) {
      debugPrint('[GoogleAuthService] Sign-in error: $e');
      return false;
    }
  }

  /// ユーザープロフィールの取得と保存
  Future<void> _fetchAndSaveUserProfile(AuthClient authClient) async {
    try {
      final response = await authClient.get(
        Uri.parse('https://www.googleapis.com/oauth2/v2/userinfo'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> userInfo = jsonDecode(response.body);
        final email = userInfo['email'] as String?;
        final name = userInfo['name'] as String?;
        final photoUrl = userInfo['picture'] as String?;

        if (email != null) {
          userEmailNotifier.value = email;
          await StorageService.setGoogleUserEmail(email);
        }
        if (name != null) {
          userNameNotifier.value = name;
          await StorageService.setGoogleUserName(name);
        }
        if (photoUrl != null) {
          await StorageService.setGoogleUserPhotoUrl(photoUrl);
        }
      }
    } catch (e) {
      debugPrint('[GoogleAuthService] Error fetching user profile: $e');
    }
  }

  /// 認証情報の JSON 保存
  Future<void> _saveCredentials(AccessCredentials credentials) async {
    try {
      final data = {
        'clientId': _clientId,
        'accessToken': {
          'type': credentials.accessToken.type,
          'data': credentials.accessToken.data,
          'expiry': credentials.accessToken.expiry.toIso8601String(),
        },
        'refreshToken': credentials.refreshToken,
        'scopes': credentials.scopes,
        'idToken': credentials.idToken,
      };
      await StorageService.setGoogleAuthJson(jsonEncode(data));
    } catch (e) {
      debugPrint('[GoogleAuthService] Error saving credentials: $e');
    }
  }

  /// 有効な認証クライアントを返却（必要に応じてトークン自動更新）
  Future<AutoRefreshingAuthClient?> getAuthenticatedClient() async {
    if (_authenticatedClient != null) {
      return _authenticatedClient;
    }
    final success = await init();
    if (success) {
      return _authenticatedClient;
    }
    return null;
  }

  /// ログアウト
  Future<void> signOut() async {
    try {
      _authenticatedClient?.close();
      _authenticatedClient = null;
      isSignedInNotifier.value = false;
      userEmailNotifier.value = null;
      userNameNotifier.value = null;
      await StorageService.clearGoogleAuth();
      debugPrint('[GoogleAuthService] Signed out successfully');
    } catch (e) {
      debugPrint('[GoogleAuthService] Error during signOut: $e');
    }
  }
}
