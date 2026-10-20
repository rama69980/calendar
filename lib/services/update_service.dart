import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'tray_and_window_service.dart';

/// GitHub Releases にある新しいバージョン
class AppUpdate {
  final String version;
  final String currentVersion;
  final String downloadUrl;
  final String notes;

  const AppUpdate({
    required this.version,
    required this.currentVersion,
    required this.downloadUrl,
    this.notes = '',
  });
}

/// "2.1.0" 形式のバージョン比較 (先頭の v と +build は無視)。a が新しければ正
int compareVersions(String a, String b) {
  List<int> parse(String v) => v
      .trim()
      .replaceFirst(RegExp(r'^[vV]'), '')
      .split('+')
      .first
      .split('.')
      .map((part) => int.tryParse(RegExp(r'^\d+').stringMatch(part) ?? '') ?? 0)
      .toList();

  final x = parse(a);
  final y = parse(b);
  for (var i = 0; i < 3; i++) {
    final diff = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (diff != 0) return diff;
  }
  return 0;
}

/// アプリ起動時に最新の Release を確認し、インストーラーを落として静かに上書きインストールする
///
/// 1. releases/latest の tag_name (例: v2.1.0) と今のバージョンを比べる
/// 2. 新しければ assets の 〜Setup〜.exe を一時フォルダにダウンロード
/// 3. Inno Setup の /SILENT で起動してアプリを終了 → インストール後に新しいアプリが起動する
class UpdateService {
  static final UpdateService instance = UpdateService._();
  UpdateService._();

  static const String releasesApi = String.fromEnvironment(
    'CALENDAR_RELEASES_API',
    defaultValue: 'https://api.github.com/repos/rama69980/calendar/releases/latest',
  );

  static final RegExp _setupAsset = RegExp(r'setup.*\.exe$', caseSensitive: false);

  /// テストで差し替え可能
  @visibleForTesting
  http.Client httpClient = http.Client();

  @visibleForTesting
  Future<String> Function() currentVersion =
      () async => (await PackageInfo.fromPlatform()).version;

  /// Windows の配布版だけ (テスト実行中は確認しない)
  @visibleForTesting
  bool isSupported = Platform.isWindows && !Platform.environment.containsKey('FLUTTER_TEST');

  /// 新しいバージョンがあれば返す。無い・確認できないときは null
  Future<AppUpdate?> checkForUpdate() async {
    if (!isSupported) return null;
    try {
      final response = await httpClient.get(
        Uri.parse(releasesApi),
        headers: {'Accept': 'application/vnd.github+json'},
      );
      if (response.statusCode != 200) return null;

      final release = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (release['draft'] == true || release['prerelease'] == true) return null;

      final latest = (release['tag_name'] as String? ?? '').replaceFirst(RegExp(r'^[vV]'), '');
      final current = await currentVersion();
      if (latest.isEmpty || compareVersions(latest, current) <= 0) return null;

      final assets = (release['assets'] as List? ?? const []).whereType<Map<String, dynamic>>();
      final setup = assets.where((a) => _setupAsset.hasMatch(a['name'] as String? ?? '')).firstOrNull;
      final url = setup?['browser_download_url'] as String?;
      if (url == null) return null;

      return AppUpdate(
        version: latest,
        currentVersion: current,
        downloadUrl: url,
        notes: (release['body'] as String? ?? '').trim(),
      );
    } catch (e) {
      debugPrint('[UpdateService] Update check failed: $e');
      return null;
    }
  }

  /// インストーラーを一時フォルダに保存する。onProgress は 0.0〜1.0 (サイズ不明なら呼ばない)
  Future<File> download(AppUpdate update, {ValueChanged<double>? onProgress, Directory? into}) async {
    final response = await httpClient.send(http.Request('GET', Uri.parse(update.downloadUrl)));
    if (response.statusCode != 200) {
      throw HttpException('ダウンロードに失敗しました (${response.statusCode})');
    }

    final dir = into ?? Directory.systemTemp;
    final file = File('${dir.path}${Platform.pathSeparator}CalendarSetup-${update.version}.exe');
    final sink = file.openWrite();
    final total = response.contentLength ?? 0;
    var received = 0;
    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress?.call(received / total);
      }
    } finally {
      await sink.close();
    }
    return file;
  }

  /// インストーラーを静かに起動してアプリを終了する (インストール完了後に新しいアプリが起動)
  Future<void> installAndExit(File installer) async {
    await Process.start(
      installer.path,
      ['/SILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/CLOSEAPPLICATIONS', '/LANG=japanese'],
      mode: ProcessStartMode.detached,
    );
    await TrayAndWindowService.instance.exitApp();
  }
}
