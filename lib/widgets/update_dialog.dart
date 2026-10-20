import 'package:flutter/material.dart';
import '../services/update_service.dart';

/// 新しいバージョンのお知らせ → ダウンロード → 自動インストール
class UpdateDialog extends StatefulWidget {
  final AppUpdate update;

  const UpdateDialog({super.key, required this.update});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _downloading = false;
  double? _progress;
  String? _error;

  Future<void> _startUpdate() async {
    setState(() {
      _downloading = true;
      _progress = null;
      _error = null;
    });
    try {
      final installer = await UpdateService.instance.download(
        widget.update,
        onProgress: (value) {
          if (mounted) setState(() => _progress = value);
        },
      );
      await UpdateService.instance.installAndExit(installer);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _error = 'アップデートに失敗しました。時間をおいてもう一度お試しください。\n$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final update = widget.update;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.system_update_alt_rounded),
          SizedBox(width: 8),
          Text('新しいバージョンがあります'),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('バージョン ${update.version} が公開されました（現在 ${update.currentVersion}）。'),
            const SizedBox(height: 4),
            const Text('アップデートしますか？ インストール後にアプリが自動で再起動します。'),
            if (update.notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(maxHeight: 160),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(update.notes, style: const TextStyle(fontSize: 12.5)),
                ),
              ),
            ],
            if (_downloading) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 6),
              Text(
                _progress == null ? 'ダウンロード中…' : 'ダウンロード中… ${(_progress! * 100).round()}%',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(fontSize: 12, color: colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _downloading ? null : () => Navigator.of(context).pop(),
          child: const Text('後で'),
        ),
        FilledButton.icon(
          onPressed: _downloading ? null : _startUpdate,
          icon: const Icon(Icons.download_rounded, size: 18),
          label: Text(_error == null ? '今すぐアップデート' : '再試行'),
        ),
      ],
    );
  }
}
