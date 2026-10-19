import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// PKCE (RFC 7636) — ブラウザ経由のログインで受け取ったコードを、このアプリだけがトークンに交換できるようにする
class Pkce {
  final String verifier;
  final String challenge;

  Pkce._(this.verifier) : challenge = challengeOf(verifier);

  factory Pkce.generate() => Pkce._(randomUrlSafe(32));

  /// code_challenge = BASE64URL(SHA-256(code_verifier))
  static String challengeOf(String verifier) =>
      _base64UrlNoPad(sha256.convert(ascii.encode(verifier)).bytes);

  static String randomUrlSafe(int byteLength) {
    final random = Random.secure();
    return _base64UrlNoPad(List<int>.generate(byteLength, (_) => random.nextInt(256)));
  }

  static String _base64UrlNoPad(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');
}
