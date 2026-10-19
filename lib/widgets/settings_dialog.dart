import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/google_auth_service.dart';
import '../services/google_calendar_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/tray_and_window_service.dart';
import 'web_account_section.dart';

class SettingsDialog extends StatefulWidget {
  final ValueChanged<bool>? onThemeChanged;

  const SettingsDialog({super.key, this.onThemeChanged});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late bool _autoStart;
  late bool _minimizeToTray;
  late bool _darkMode;
  late bool _googleAutoSync;
  bool _isLoggingIn = false;

  @override
  void initState() {
    super.initState();
    _autoStart = StorageService.getAutoStart();
    _minimizeToTray = StorageService.getMinimizeToTray();
    _darkMode = StorageService.getDarkMode();
    _googleAutoSync = StorageService.getGoogleAutoSync();
  }

  Future<void> _handleGoogleSignIn() async {
    if (!GoogleAuthService.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Google 連携の設定 (OAuth クライアント) がこのビルドに含まれていません。'),
          backgroundColor: Color(0xFFEF4444),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() {
      _isLoggingIn = true;
    });

    final success = await GoogleAuthService.instance.signIn();

    if (mounted) {
      setState(() {
        _isLoggingIn = false;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google アカウント (${GoogleAuthService.instance.userEmail}) と連携しました。'),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 3),
          ),
        );
        // 連携直後に初回同期を実行
        GoogleCalendarService.instance.syncAll();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google ログインに失敗しました。もう一度お試しください。'),
            backgroundColor: Color(0xFFEF4444),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _handleGoogleSignOut() async {
    await GoogleAuthService.instance.signOut();
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Google アカウントの連携を解除しました。'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _handleManualSync() async {
    final success = await GoogleCalendarService.instance.syncAll();
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Google カレンダーと同期しました。'),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('同期エラー: ${GoogleCalendarService.instance.syncError.value ?? "不明なエラー"}'),
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 540,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.settings,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  '環境設定',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Scrollable Settings Content
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // calendarWEB アカウント (ブラウザ連携ログイン)
                    const WebAccountSection(),
                    const SizedBox(height: 16),

                    // ==========================================
                    // 🌟 Google Calendar Integration Section
                    // ==========================================
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.calendar_month,
                                  color: Color(0xFF4285F4),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Google カレンダー リアルタイム同期',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          ValueListenableBuilder<bool>(
                            valueListenable: GoogleAuthService.instance.isSignedInNotifier,
                            builder: (context, isSignedIn, _) {
                              if (isSignedIn) {
                                final email = GoogleAuthService.instance.userEmail ?? 'ログイン中';
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.check_circle,
                                          color: Color(0xFF10B981),
                                          size: 18,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            email,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13.5,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: _handleGoogleSignOut,
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.red.shade400,
                                            visualDensity: VisualDensity.compact,
                                          ),
                                          child: const Text('連携解除'),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),

                                    // Last sync time & manual sync button
                                    ValueListenableBuilder<DateTime?>(
                                      valueListenable: GoogleCalendarService.instance.lastSyncTime,
                                      builder: (context, lastTime, _) {
                                        final syncTimeStr = lastTime != null
                                            ? DateFormat('MM/dd HH:mm').format(lastTime)
                                            : '同期履歴なし';
                                        return Row(
                                          children: [
                                            Text(
                                              '最終同期: $syncTimeStr',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                            const Spacer(),
                                            ValueListenableBuilder<bool>(
                                              valueListenable: GoogleCalendarService.instance.isSyncing,
                                              builder: (context, isSyncing, _) {
                                                return FilledButton.tonalIcon(
                                                  onPressed: isSyncing ? null : _handleManualSync,
                                                  icon: isSyncing
                                                      ? const SizedBox(
                                                          width: 14,
                                                          height: 14,
                                                          child: CircularProgressIndicator(strokeWidth: 2),
                                                        )
                                                      : const Icon(Icons.sync, size: 16),
                                                  label: Text(isSyncing ? '同期中...' : '今すぐ同期'),
                                                  style: FilledButton.styleFrom(
                                                    visualDensity: VisualDensity.compact,
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 8),

                                    // Auto sync switch
                                    SwitchListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: const Text(
                                        '自動同期',
                                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                                      ),
                                      subtitle: const Text(
                                        '予定の変更時にスマホの Google カレンダーへ自動反映します。',
                                        style: TextStyle(fontSize: 11.5),
                                      ),
                                      value: _googleAutoSync,
                                      onChanged: (val) async {
                                        setState(() {
                                          _googleAutoSync = val;
                                        });
                                        await StorageService.setGoogleAutoSync(val);
                                      },
                                    ),
                                  ],
                                );
                              } else {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Google アカウントを連携すると、PC で登録した予定がスマートフォンの Google カレンダーと双方向で自動同期されます。',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: FilledButton.icon(
                                        onPressed: _isLoggingIn ? null : _handleGoogleSignIn,
                                        icon: _isLoggingIn
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : const Icon(Icons.login),
                                        label: Text(_isLoggingIn
                                            ? 'ブラウザでログイン待機中...'
                                            : 'Google アカウントと連携する'),
                                      ),
                                    ),
                                  ],
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ==========================================
                    // System & General Settings
                    // ==========================================
                    // 1. Auto-start on boot
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.power_settings_new),
                      title: const Text(
                        'PC起動時に自動起動',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                      ),
                      subtitle: const Text(
                        'パソコン起動時にバックグラウンド（トレイ）で起動し、通知を待機します。',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: _autoStart,
                      onChanged: (val) async {
                        setState(() {
                          _autoStart = val;
                        });
                        await TrayAndWindowService.instance.toggleAutoStart(val);
                      },
                    ),
                    const Divider(height: 20),

                    // 2. Minimize to tray on close
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.archive_outlined),
                      title: const Text(
                        'ウィンドウを閉じた時にトレイへ最小化',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                      ),
                      subtitle: const Text(
                        '×ボタンを押してもアプリを終了せず、トレイに常駐して通知を維持します。',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: _minimizeToTray,
                      onChanged: (val) async {
                        setState(() {
                          _minimizeToTray = val;
                        });
                        await StorageService.setMinimizeToTray(val);
                      },
                    ),
                    const Divider(height: 20),

                    // 3. Dark mode
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.dark_mode_outlined),
                      title: const Text(
                        'ダークモード',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                      ),
                      subtitle: const Text(
                        'ダークテーマに切り替えます。',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: _darkMode,
                      onChanged: (val) async {
                        setState(() {
                          _darkMode = val;
                        });
                        await StorageService.setDarkMode(val);
                        widget.onThemeChanged?.call(val);
                      },
                    ),
                    const Divider(height: 20),

                    // 4. Test Notification Button
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.notifications_active_outlined),
                      title: const Text(
                        'Windows通知テスト',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                      ),
                      subtitle: const Text(
                        'Windowsのトースト通知が正常に表示されるか確認します。',
                        style: TextStyle(fontSize: 12),
                      ),
                      trailing: FilledButton.tonal(
                        onPressed: () {
                          NotificationService.showTestNotification();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('テスト通知を送信しました。'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        child: const Text('通知テスト'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('閉じる'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

