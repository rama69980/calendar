import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/calendar_screen.dart';
import 'services/google_auth_service.dart';
import 'services/google_calendar_service.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'services/tray_and_window_service.dart';
import 'services/web_account_service.dart';
import 'services/member_service.dart';

Future<bool> _ensureSingleInstance() async {
  if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    return true;
  }

  const int singleInstancePort = 49281;
  try {
    final server =
        await ServerSocket.bind(InternetAddress.loopbackIPv4, singleInstancePort);
    server.listen((socket) {
      socket.listen((data) {
        final message = String.fromCharCodes(data).trim();
        if (message == 'show') {
          TrayAndWindowService.instance.showAppWindow();
        }
      });
    });
    return true; // 最初のインスタンス
  } catch (e) {
    // 既に起動しているインスタンスへフォーカス指示を送信して終了
    try {
      final socket =
          await Socket.connect(InternetAddress.loopbackIPv4, singleInstancePort);
      socket.write('show');
      await socket.flush();
      await socket.close();
    } catch (_) {}
    return false; // 重複起動のため終了
  }
}

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // 単一インスタンス制御 (重複起動防止)
  final isPrimary = await _ensureSingleInstance();
  if (!isPrimary) {
    exit(0);
  }

  // 日付ロケール初期化 (日本語)
  try {
    await initializeDateFormatting('ja_JP', null);
  } catch (e) {
    debugPrint('Locale initialization error: $e');
  }

  // 1. ローカルストレージ初期化
  await StorageService.init();

  // 2. Google サービス初期化
  GoogleCalendarService.instance.init();
  GoogleAuthService.instance.init().then((isLoggedIn) {
    if (isLoggedIn && StorageService.getGoogleAutoSync()) {
      GoogleCalendarService.instance.syncAll();
    }
  });

  // 2-1. calendarWEB アカウント (保存済みトークンで自動ログイン)
  WebAccountService.instance.init();

  // 2-2. 社員どうしの予定共有 (ログイン中は自分の予定を自動アップロード)
  MemberService.instance.start();

  // 3. 通知サービス初期化
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await NotificationService.init();
  }

  // 4. PC起動時の自動起動チェック (--autostart / --minimized)
  final isAutoStartLaunch =
      args.contains('--autostart') || args.contains('--minimized');

  // 5. システムトレイ＆ウィンドウマネージャー初期化
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await TrayAndWindowService.instance.init(
      isAutoStartLaunch: isAutoStartLaunch,
    );
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late bool _isDarkMode;

  @override
  void initState() {
    super.initState();
    _isDarkMode = StorageService.getDarkMode();
  }

  void _toggleTheme(bool isDark) {
    setState(() {
      _isDarkMode = isDark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'スケジュール＆カレンダー',
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF3B82F6),
        brightness: Brightness.light,
        fontFamily: 'Yu Gothic UI',
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF60A5FA),
        brightness: Brightness.dark,
        fontFamily: 'Yu Gothic UI',
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E293B),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF334155)),
          ),
        ),
      ),
      home: CalendarScreen(
        onThemeChanged: _toggleTheme,
      ),
    );
  }
}