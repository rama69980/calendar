import 'dart:convert';
import 'dart:io';

import 'package:calendar/services/update_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('compareVersions', () {
    test('compares numerically and ignores v prefix and build number', () {
      expect(compareVersions('2.1.0', '2.0.0'), greaterThan(0));
      expect(compareVersions('v2.10.0', '2.9.9'), greaterThan(0));
      expect(compareVersions('2.1.0+5', '2.1.0'), 0);
      expect(compareVersions('2.1', '2.1.0'), 0);
      expect(compareVersions('1.0.0', 'v2.0.0'), lessThan(0));
    });
  });

  group('UpdateService', () {
    final service = UpdateService.instance;

    Map<String, dynamic> release(String tag, {List<String> assets = const ['CalendarSetup.exe']}) => {
          'tag_name': tag,
          'draft': false,
          'prerelease': false,
          'body': '検索に期間フィルター',
          'assets': [
            for (final name in assets)
              {'name': name, 'browser_download_url': 'https://example.com/$name'},
          ],
        };

    void respond(Map<String, dynamic> body) {
      service.httpClient = MockClient((_) async => http.Response.bytes(utf8.encode(jsonEncode(body)), 200));
    }

    setUp(() {
      service.isSupported = true;
      service.currentVersion = () async => '2.1.0';
    });

    test('a newer release with a setup exe is offered', () async {
      respond(release('v2.2.0', assets: ['Calendar-MacOS-App.zip', 'CalendarSetup-x64.exe']));
      final update = await service.checkForUpdate();
      expect(update?.version, '2.2.0');
      expect(update?.currentVersion, '2.1.0');
      expect(update?.downloadUrl, 'https://example.com/CalendarSetup-x64.exe');
      expect(update?.notes, '検索に期間フィルター');
    });

    test('same or older release, or no installer, is ignored', () async {
      respond(release('v2.1.0'));
      expect(await service.checkForUpdate(), isNull);
      respond(release('v2.0.0'));
      expect(await service.checkForUpdate(), isNull);
      respond(release('v3.0.0', assets: ['Calendar-MacOS-App.zip']));
      expect(await service.checkForUpdate(), isNull);
    });

    test('network errors and unsupported platforms return null', () async {
      service.httpClient = MockClient((_) async => throw const SocketException('offline'));
      expect(await service.checkForUpdate(), isNull);
      service.isSupported = false;
      respond(release('v9.0.0'));
      expect(await service.checkForUpdate(), isNull);
    });

    test('download saves the installer and reports progress', () async {
      final bytes = List<int>.generate(1000, (i) => i % 256);
      service.httpClient = MockClient.streaming((request, _) async =>
          http.StreamedResponse(Stream.fromIterable([bytes.sublist(0, 400), bytes.sublist(400)]), 200,
              contentLength: bytes.length));
      final dir = await Directory.systemTemp.createTemp('update_test');
      addTearDown(() => dir.delete(recursive: true));

      final progress = <double>[];
      final file = await service.download(
        const AppUpdate(version: '2.2.0', currentVersion: '2.1.0', downloadUrl: 'https://example.com/a.exe'),
        onProgress: progress.add,
        into: dir,
      );

      expect(file.path, endsWith('CalendarSetup-2.2.0.exe'));
      expect(await file.readAsBytes(), bytes);
      expect(progress, [0.4, 1.0]);
    });
  });
}
