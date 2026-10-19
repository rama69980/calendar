import 'package:calendar/services/google_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('OAuth client is not configured unless injected with --dart-define', () {
    const injected = String.fromEnvironment('GOOGLE_CLIENT_ID');
    expect(GoogleAuthService.isConfigured, injected.isNotEmpty);
  });
}
