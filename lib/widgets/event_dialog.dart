import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/schedule_event.dart';
import '../services/google_auth_service.dart';
import 'color_picker_widget.dart';

class EventDialog extends StatefulWidget {
  final ScheduleEvent? event;
  final DateTime? initialDate;

  const EventDialog({
    super.key,
    this.event,
    this.initialDate,
  });

  @override
  State<EventDialog> createState() => _EventDialogState();
}

class _EventDialogState extends State<EventDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;

  late DateTime _selectedDate;
  late bool _hasTime;
  late TimeOfDay _selectedTime;
  late int _selectedColorValue;
  late bool _enableNotification;
  late int _notificationOffsetMinutes;
  late bool _isPrivate;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    if (event != null) {
      _titleController = TextEditingController(text: event.title);
      _descriptionController = TextEditingController(text: event.description);
      _selectedDate = event.date;
      _hasTime = event.hasTime;
      _selectedTime = TimeOfDay(hour: event.hour, minute: event.minute);
      _selectedColorValue = event.colorValue;
      _enableNotification = event.enableNotification;
      _notificationOffsetMinutes = event.notificationOffsetMinutes;
      _isPrivate = event.isPrivate;
    } else {
      _titleController = TextEditingController();
      _descriptionController = TextEditingController();
      _selectedDate = widget.initialDate ?? DateTime.now();
      _hasTime = true;
      final now = DateTime.now();
      _selectedTime = TimeOfDay(hour: (now.hour + 1) % 24, minute: 0);
      _selectedColorValue = 0xFF3B82F6; // Default blue
      _enableNotification = true;
      _notificationOffsetMinutes = 0; // 時間ちょうど
      _isPrivate = false;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final isEdit = widget.event != null;
    final event = ScheduleEvent(
      id: isEdit ? widget.event!.id : const Uuid().v4(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      date: DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day),
      hasTime: _hasTime,
      hour: _selectedTime.hour,
      minute: _selectedTime.minute,
      colorValue: _selectedColorValue,
      isCompleted: isEdit ? widget.event!.isCompleted : false,
      enableNotification: _enableNotification,
      notificationOffsetMinutes: _notificationOffsetMinutes,
      isPrivate: _isPrivate,
      googleEventId: isEdit ? widget.event!.googleEventId : null,
      etag: isEdit ? widget.event!.etag : null,
      syncStatus: isEdit
          ? (widget.event!.isGoogleSynced ? 'pendingUpdate' : widget.event!.syncStatus)
          : 'pendingUpload',
      isDeletedLocally: false,
      isNotified: isEdit
          ? (widget.event!.hasTime == _hasTime &&
                  widget.event!.hour == _selectedTime.hour &&
                  widget.event!.minute == _selectedTime.minute &&
                  widget.event!.date == _selectedDate &&
                  widget.event!.notificationOffsetMinutes == _notificationOffsetMinutes
              ? widget.event!.isNotified
              : false)
          : false,
      createdAt: isEdit ? widget.event!.createdAt : DateTime.now(),
      updatedAt: DateTime.now(),
    );

    Navigator.of(context).pop(event);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.event != null;
    final dateFormat = DateFormat('yyyy年MM月dd日 (E)', 'ja_JP');
    final timeFormat = NumberFormat('00');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 520,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
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
                      color: Color(_selectedColorValue).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isEdit ? Icons.edit_calendar : Icons.add_task,
                      color: Color(_selectedColorValue),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isEdit ? '予定の編集' : '新しい予定の追加',
                    style: const TextStyle(
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
              const SizedBox(height: 20),

              // Form Body
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title input
                      TextFormField(
                        controller: _titleController,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: 'タイトル',
                          hintText: '予定のタイトルを入力',
                          prefixIcon: const Icon(Icons.title),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'タイトルを入力してください。';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Description input
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'メモ / 詳細 (任意)',
                          hintText: '詳細内容を入力',
                          prefixIcon: const Icon(Icons.notes),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Date & Time Picker
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.calendar_month, size: 20),
                              label: Text(
                                () {
                                  try {
                                    return dateFormat.format(_selectedDate);
                                  } catch (_) {
                                    return '${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}';
                                  }
                                }(),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              onPressed: _pickDate,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (_hasTime)
                            Expanded(
                              flex: 2,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(Icons.access_time, size: 20),
                                label: Text(
                                  '${timeFormat.format(_selectedTime.hour)}:${timeFormat.format(_selectedTime.minute)}',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                                onPressed: _pickTime,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Time toggle
                      Row(
                        children: [
                          Checkbox(
                            value: !_hasTime,
                            onChanged: (val) {
                              setState(() {
                                _hasTime = !(val ?? false);
                              });
                            },
                          ),
                          const Text('終日 (時間未指定)', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                      const Divider(height: 24),

                      // Color Picker
                      ColorPickerWidget(
                        selectedColorValue: _selectedColorValue,
                        onColorChanged: (colorVal) {
                          setState(() {
                            _selectedColorValue = colorVal;
                          });
                        },
                      ),
                      const Divider(height: 24),

                      // Notification Settings
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.notifications_active_outlined,
                                color: _enableNotification
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                '通知を受け取る',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Switch(
                            value: _enableNotification,
                            onChanged: (val) {
                              setState(() {
                                _enableNotification = val;
                              });
                            },
                          ),
                        ],
                      ),

                      if (_enableNotification) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              isExpanded: true,
                              value: _notificationOffsetMinutes,
                              items: const [
                                DropdownMenuItem(value: 0, child: Text('予定時刻（時間ちょうど）')),
                                DropdownMenuItem(value: 10, child: Text('10分前')),
                                DropdownMenuItem(value: 30, child: Text('30分前')),
                                DropdownMenuItem(value: 60, child: Text('1時間前')),
                                DropdownMenuItem(value: 1440, child: Text('1日前')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _notificationOffsetMinutes = val;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ],

                      const Divider(height: 24),

                      // チームに公開するか (非公開ならメンバーには「予定あり」と時間だけ見える)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  _isPrivate ? Icons.lock_outline : Icons.groups_outlined,
                                  color: _isPrivate ? Colors.grey : Theme.of(context).colorScheme.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '非公開にする',
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                      ),
                                      Text(
                                        _isPrivate
                                            ? 'チームのメンバーには「予定あり」と時間だけ表示されます'
                                            : 'チームのメンバーにタイトルとメモが表示されます',
                                        style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _isPrivate,
                            onChanged: (val) => setState(() => _isPrivate = val),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Google Calendar sync info banner
              if (GoogleAuthService.instance.isSignedIn)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4285F4).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF4285F4).withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.cloud_done, size: 16, color: Color(0xFF4285F4)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Google カレンダーとリアルタイム同期され、スマホでも確認・通知を受信できます。',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF1E40AF),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('キャンセル'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Color(_selectedColorValue),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: Icon(isEdit ? Icons.check : Icons.add),
                    label: Text(isEdit ? '更新' : '保存'),
                    onPressed: _save,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
