import 'package:flutter/material.dart';
import '../services/web_account_service.dart';

/// 環境設定の「calendarWEB アカウント」セクション
class WebAccountSection extends StatefulWidget {
  const WebAccountSection({super.key});

  @override
  State<WebAccountSection> createState() => _WebAccountSectionState();
}

class _WebAccountSectionState extends State<WebAccountSection> {
  bool _isLoggingIn = false;

  Future<void> _handleSignIn() async {
    setState(() => _isLoggingIn = true);
    final result = await WebAccountService.instance.signIn();
    if (!mounted) return;
    setState(() => _isLoggingIn = false);

    final (String message, Color? color) = switch (result) {
      WebSignInResult.success => (
          'calendarWEB アカウント (${WebAccountService.instance.account?.email}) でログインしました。',
          const Color(0xFF10B981)
        ),
      WebSignInResult.cancelled => ('ログインをキャンセルしました。', null),
      WebSignInResult.timeout => ('ログインがタイムアウトしました。もう一度お試しください。', const Color(0xFFEF4444)),
      WebSignInResult.failed => (
          'ログインに失敗しました。calendarWEB のサーバーに接続できるか確認してください。',
          const Color(0xFFEF4444)
        ),
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, duration: const Duration(seconds: 3)),
    );
  }

  Future<void> _handleSignOut() async {
    await WebAccountService.instance.signOut();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('calendarWEB アカウントからログアウトしました。'), duration: Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_circle_outlined, color: colorScheme.primary, size: 22),
              const SizedBox(width: 10),
              const Text(
                'calendarWEB アカウント',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<WebAccount?>(
            valueListenable: WebAccountService.instance.accountNotifier,
            builder: (context, account, _) =>
                account != null ? _buildSignedIn(account, colorScheme) : _buildSignedOut(colorScheme),
          ),
        ],
      ),
    );
  }

  Widget _buildSignedIn(WebAccount account, ColorScheme colorScheme) {
    final imageUrl = account.imageUrl;
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: colorScheme.primaryContainer,
          foregroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
          child: Text(
            account.displayName.characters.first.toUpperCase(),
            style: TextStyle(color: colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                account.displayName,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
              if (account.displayName != account.email)
                Text(
                  account.email,
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        TextButton(
          onPressed: _handleSignOut,
          style: TextButton.styleFrom(
            foregroundColor: Colors.red.shade400,
            visualDensity: VisualDensity.compact,
          ),
          child: const Text('ログアウト'),
        ),
      ],
    );
  }

  Widget _buildSignedOut(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ブラウザで calendarWEB にログインすると、このアプリでも同じアカウントが使えます。',
          style: TextStyle(fontSize: 12.5, color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _isLoggingIn ? null : _handleSignIn,
                icon: _isLoggingIn
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.login),
                label: Text(_isLoggingIn ? 'ブラウザでログイン待機中...' : 'calendarWEB でログイン'),
              ),
            ),
            if (_isLoggingIn) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: WebAccountService.instance.cancelSignIn,
                child: const Text('キャンセル'),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
