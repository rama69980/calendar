import 'dart:convert';
import 'dart:io';
import 'package:calendar/services/pkce.dart';
import 'package:calendar/services/storage_service.dart';
import 'package:calendar/services/web_account_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final service = WebAccountService.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    await service.signOut();
  });

  group('Pkce', () {
    test('matches RFC 7636 example', () {
      expect(
        Pkce.challengeOf('dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk'),
        'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
      );
    });

    test('generated verifier is url-safe and 43 chars', () {
      final pkce = Pkce.generate();
      expect(pkce.verifier, matches(RegExp(r'^[A-Za-z0-9_-]{43}$')));
      expect(pkce.challenge, Pkce.challengeOf(pkce.verifier));
    });
  });

  /// ブラウザの代わりに: Web が loopback に code を返す動きを再現する
  Future<bool> Function(Uri) fakeBrowser(Map<String, String> Function(Uri loginUrl) callbackQuery) {
    return (loginUrl) async {
      final redirect = Uri.parse(loginUrl.queryParameters['redirect_uri']!);
      final client = HttpClient();
      final request = await client.getUrl(redirect.replace(queryParameters: callbackQuery(loginUrl)));
      await (await request.close()).drain<void>();
      client.close();
      return true;
    };
  }

  test('signIn exchanges code with PKCE verifier and stores the account', () async {
    String? sentChallenge;
    service.openBrowser = fakeBrowser((loginUrl) {
      sentChallenge = loginUrl.queryParameters['code_challenge'];
      return {'code': 'one-time-code', 'state': loginUrl.queryParameters['state']!};
    });
    service.httpClient = MockClient((request) async {
      if (request.url.path == '/api/auth/desktop/token') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['code'], 'one-time-code');
        expect(Pkce.challengeOf(body['codeVerifier'] as String), sentChallenge);
        expect(body['redirectUri'], startsWith('http://127.0.0.1:'));
        return http.Response(jsonEncode({'email': 'a@b.com', 'token': 'app-token'}), 200);
      }
      if (request.url.path == '/api/auth/userinformation') {
        expect(request.headers['Authorization'], 'Bearer app-token');
        return http.Response(
          jsonEncode({'email': 'a@b.com', 'usernickname': 'ニック', 'profileImage': 'p.png'}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response('', 404);
    });

    final result = await service.signIn();

    expect(result, WebSignInResult.success);
    expect(service.account?.displayName, 'ニック');
    expect(service.account?.imageUrl, endsWith('/uploads/p.png'));
    expect(StorageService.getWebAccountToken(), 'app-token');
  });

  test('signIn rejects a callback with the wrong state', () async {
    service.openBrowser = fakeBrowser((_) => {'code': 'x', 'state': 'forged'});
    service.httpClient = MockClient((_) async => fail('must not call backend'));

    expect(await service.signIn(), WebSignInResult.failed);
    expect(service.isSignedIn, isFalse);
  });

  test('cancel on the web returns cancelled', () async {
    service.openBrowser =
        fakeBrowser((loginUrl) => {'error': 'access_denied', 'state': loginUrl.queryParameters['state']!});
    service.httpClient = MockClient((_) async => fail('must not call backend'));

    expect(await service.signIn(), WebSignInResult.cancelled);
  });

  test('init signs out when the saved token is rejected', () async {
    await StorageService.setWebAccount('old-token', jsonEncode({'email': 'a@b.com'}));
    service.httpClient = MockClient((_) async => http.Response('{"message":"x"}', 401));

    await service.init();

    expect(service.isSignedIn, isFalse);
    expect(StorageService.getWebAccountToken(), isNull);
  });

  test('init keeps the saved account when offline', () async {
    await StorageService.setWebAccount('token', jsonEncode({'email': 'a@b.com', 'usernickname': 'n'}));
    service.httpClient = MockClient((_) async => throw const SocketException('offline'));

    await service.init();

    expect(service.account?.displayName, 'n');
  });
}
