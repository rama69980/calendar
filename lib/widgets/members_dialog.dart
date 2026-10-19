import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/member_service.dart';
import '../services/web_account_service.dart';

/// 社員メンバー画面: 自分の社員ステータス / 社員申請 / メンバー一覧 / 社員登録用 QR コード
class MembersDialog extends StatefulWidget {
  const MembersDialog({super.key});

  @override
  State<MembersDialog> createState() => _MembersDialogState();
}

class _MembersDialogState extends State<MembersDialog> {
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (WebAccountService.instance.isSignedIn) {
      MemberService.instance.refreshMembers().whenComplete(() {
        if (mounted) setState(() => _loading = false);
      });
    } else {
      _loading = false;
    }
  }

  Future<void> _requestEmployee() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await MemberService.instance.requestEmployee();
    } on MemberException catch (e) {
      _error = e.message;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.groups_rounded),
                  const SizedBox(width: 10),
                  const Text('社員メンバー', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(child: SingleChildScrollView(child: _buildBody())),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (!WebAccountService.instance.isSignedIn) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text(
          '社員の予定を見るには、設定 → 「calendarWEB アカウント」でログインしてください。',
          textAlign: TextAlign.center,
        ),
      );
    }
    if (_loading) {
      return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
    }
    return ValueListenableBuilder<WebAccount?>(
      valueListenable: WebAccountService.instance.accountNotifier,
      builder: (context, account, _) {
        if (account == null) return const SizedBox.shrink();
        if (account.memberAccess) return _buildMembers(account);
        return _buildStatus(account);
      },
    );
  }

  /// まだ社員として承認されていない人向け
  Widget _buildStatus(WebAccount account) {
    final (icon, color, text) = switch (account.employeeStatus) {
      'PENDING' => (Icons.hourglass_top, Colors.orange, '社員申請中です。管理者の承認をお待ちください。\n承認されるとメンバーの予定を確認できます。'),
      'REJECTED' => (Icons.block, Colors.red, '社員申請が却下されました。必要なら管理者に確認のうえ、もう一度申請してください。'),
      _ => (Icons.person_outline, Colors.grey, '一般ユーザーとして利用中です。\ncal の社員なら申請すると、管理者の承認後に社員の予定を共有できます。'),
    };
    final canRequest = account.employeeStatus == 'NONE' || account.employeeStatus == 'REJECTED';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Expanded(child: Text(text, style: const TextStyle(fontSize: 13, height: 1.5))),
            ],
          ),
        ),
        if (canRequest) ...[
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.badge_outlined),
            label: const Text('cal の社員として申請する'),
            onPressed: _busy ? null : _requestEmployee,
          ),
        ],
        const SizedBox(height: 8),
        TextButton.icon(
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('承認状態を更新'),
          onPressed: _busy
              ? null
              : () async {
                  setState(() => _busy = true);
                  await MemberService.instance.refreshMembers();
                  if (mounted) setState(() => _busy = false);
                },
        ),
      ],
    );
  }

  /// 管理者・承認済み社員向け
  Widget _buildMembers(WebAccount account) {
    final colorScheme = Theme.of(context).colorScheme;
    final url = MemberService.registrationUrl;
    return ValueListenableBuilder<List<MemberInfo>>(
      valueListenable: MemberService.instance.membersNotifier,
      builder: (context, members, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (account.admin)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
                label: const Text('管理者ページを開く (社員申請の承認)'),
                onPressed: () => launchUrl(Uri.parse('${WebAccountService.webBaseUrl}/AdminPage'),
                    mode: LaunchMode.externalApplication),
              ),
            ),
          Text('メンバー (${members.length}人)', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          ...members.map((m) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(radius: 16, child: Text(m.displayName.characters.first.toUpperCase())),
                title: Text(m.isMe ? '${m.displayName} (自分)' : m.displayName),
                subtitle: Text(m.email, style: const TextStyle(fontSize: 11)),
                trailing: m.isAdmin
                    ? const Chip(label: Text('管理者', style: TextStyle(fontSize: 11)), visualDensity: VisualDensity.compact)
                    : null,
              )),
          const SizedBox(height: 16),

          // 社員登録用 QR コード
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Text('社員を招待', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                const Text(
                  'スマホで読み取ると calendarWEB の会員登録画面が開きます。\n登録後、管理者が承認すると予定を共有できます。',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(8),
                  child: QrImageView(data: url, size: 180, backgroundColor: Colors.white),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  icon: const Icon(Icons.link, size: 18),
                  label: const Text('URL をコピー'),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: url));
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                      const SnackBar(content: Text('登録用 URL をコピーしました'), duration: Duration(seconds: 2)),
                    );
                  },
                ),
                if (WebAccountService.webBaseUrl.contains('localhost'))
                  const Text(
                    '※ 開発用ビルドのため URL が localhost です。スマホから開くには公開サーバーの URL でビルドしてください。',
                    style: TextStyle(fontSize: 11, color: Colors.orange),
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
