import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/member_service.dart';
import '../services/web_account_service.dart';
import '../utils/search_period.dart';

/// 予定検索: 期間 (年/月/週/日) + 対象 (自分・社員メンバー) + キーワード。
/// 「この日にあの人は予定があるか」をすぐ確認できるよう、上に人ごとの件数を出す。
class ScheduleSearchDialog extends StatefulWidget {
  final DateTime initialDate;
  final String initialQuery;

  const ScheduleSearchDialog({super.key, required this.initialDate, this.initialQuery = ''});

  @override
  State<ScheduleSearchDialog> createState() => _ScheduleSearchDialogState();
}

class _ScheduleSearchDialogState extends State<ScheduleSearchDialog> {
  static const _meKey = '__me__';

  late SearchPeriod _period;
  late final TextEditingController _queryController;
  final Set<String> _selected = {_meKey};

  List<MemberSchedule> _results = [];
  bool _loading = false;
  String? _error;
  int _requestId = 0;

  /// 自分以外の社員 (社員でなければ空)
  List<MemberInfo> get _others => MemberService.instance.members.where((m) => !m.isMe).toList();

  @override
  void initState() {
    super.initState();
    _period = SearchPeriod.of(PeriodUnit.week, widget.initialDate);
    _queryController = TextEditingController(text: widget.initialQuery);
    if (WebAccountService.instance.isSignedIn) {
      MemberService.instance.refreshMembers().whenComplete(() {
        if (mounted) setState(() {});
      });
    }
    _search();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  String get _myEmail => WebAccountService.instance.account?.email ?? _meKey;
  String get _myName => WebAccountService.instance.account?.displayName ?? '自分';

  Future<void> _search() async {
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });

    // 自分の予定は端末の最新データを使う (オフラインでも検索できる)
    final mine = _selected.contains(_meKey)
        ? StorageService.loadEvents()
            .where((e) => _period.contains(e.date))
            .map((e) => MemberSchedule.fromLocal(e, ownerEmail: _myEmail, ownerName: _myName))
            .toList()
        : <MemberSchedule>[];

    final others = _selected.where((s) => s != _meKey).toList();
    var remote = <MemberSchedule>[];
    String? error;
    if (others.isNotEmpty) {
      try {
        remote = await MemberService.instance.searchSchedules(from: _period.from, to: _period.to, memberEmails: others);
      } on MemberException catch (e) {
        error = e.message;
      }
    }

    if (!mounted || requestId != _requestId) return;
    final all = [...mine, ...remote]..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        if (byDate != 0) return byDate;
        final byTime = a.sortKey.compareTo(b.sortKey);
        return byTime != 0 ? byTime : a.ownerName.compareTo(b.ownerName);
      });
    setState(() {
      _results = all;
      _error = error;
      _loading = false;
    });
  }

  List<MemberSchedule> get _filtered {
    final q = _queryController.text.trim().toLowerCase();
    if (q.isEmpty) return _results;
    return _results
        .where((s) => s.title.toLowerCase().contains(q) || s.description.toLowerCase().contains(q))
        .toList();
  }

  void _setUnit(PeriodUnit unit) {
    setState(() => _period = SearchPeriod.of(unit, _period.from));
    _search();
  }

  void _shift(int delta) {
    setState(() => _period = _period.shift(delta));
    _search();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _period.from,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );
    if (picked != null) {
      setState(() => _period = SearchPeriod.of(_period.unit, picked));
      _search();
    }
  }

  void _toggle(String key) {
    setState(() {
      if (_selected.contains(key)) {
        if (_selected.length > 1) _selected.remove(key); // 最低1人は選択
      } else {
        _selected.add(key);
      }
    });
    _search();
  }

  void _selectAll() {
    setState(() {
      _selected
        ..add(_meKey)
        ..addAll(_others.map((m) => m.email));
    });
    _search();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(24),
      child: SizedBox(
        width: size.width.clamp(360, 760).toDouble(),
        height: size.height * 0.85,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.manage_search_rounded),
                  const SizedBox(width: 10),
                  const Text('予定を検索', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 12),
              _buildPeriodBar(),
              const SizedBox(height: 12),
              TextField(
                controller: _queryController,
                decoration: InputDecoration(
                  hintText: 'キーワード (タイトル・メモ)',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixIcon: _queryController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => setState(_queryController.clear),
                        ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              _buildTargets(),
              const SizedBox(height: 12),
              _buildSummary(),
              const Divider(height: 20),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                ),
              Expanded(child: _buildResults()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodBar() {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        SegmentedButton<PeriodUnit>(
          showSelectedIcon: false,
          segments: PeriodUnit.values
              .map((u) => ButtonSegment(value: u, label: Text(u.label)))
              .toList(),
          selected: {_period.unit},
          onSelectionChanged: (s) => _setUnit(s.first),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.chevron_left), tooltip: '前へ', onPressed: () => _shift(-1)),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: _pickDate,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.event, size: 16),
                    const SizedBox(width: 6),
                    Text(_period.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            IconButton(icon: const Icon(Icons.chevron_right), tooltip: '次へ', onPressed: () => _shift(1)),
          ],
        ),
      ],
    );
  }

  Widget _buildTargets() {
    final members = _others;
    final account = WebAccountService.instance.account;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilterChip(
              avatar: const Icon(Icons.person, size: 16),
              label: const Text('自分'),
              selected: _selected.contains(_meKey),
              onSelected: (_) => _toggle(_meKey),
            ),
            ...members.map((m) => FilterChip(
                  label: Text(m.displayName),
                  tooltip: m.email,
                  selected: _selected.contains(m.email),
                  onSelected: (_) => _toggle(m.email),
                )),
            if (members.isNotEmpty) TextButton(onPressed: _selectAll, child: const Text('全員')),
          ],
        ),
        if (account == null || !account.memberAccess)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              account == null
                  ? 'calendarWEB アカウントでログインし、社員として承認されると他の社員の予定も検索できます'
                  : account.employeeStatus == 'PENDING'
                      ? '社員申請の承認待ちです。承認されると他の社員の予定も検索できます'
                      : '社員として承認されると、他の社員の予定も検索できます (右上の「メンバー」から申請)',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
      ],
    );
  }

  /// 人ごとの件数。0件なら「予定なし」= 空いている
  Widget _buildSummary() {
    if (_loading) return const LinearProgressIndicator(minHeight: 2);
    final filtered = _filtered;
    final names = <String, String>{};
    if (_selected.contains(_meKey)) names[_myEmail] = '自分';
    for (final m in _others) {
      if (_selected.contains(m.email)) names[m.email] = m.displayName;
    }

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: names.entries.map((entry) {
        final count = filtered.where((s) => s.ownerEmail == entry.key).length;
        final free = count == 0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: (free ? Colors.green : Colors.orange).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${entry.value}: ${free ? '予定なし' : '$count件'}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: free ? Colors.green.shade800 : Colors.orange.shade900,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildResults() {
    final items = _filtered;
    if (!_loading && items.isEmpty) {
      return Center(
        child: Text(
          _queryController.text.trim().isEmpty ? 'この期間に予定はありません' : '一致する予定はありません',
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    // 日付ごとにまとめる
    final rows = <Widget>[];
    DateTime? currentDate;
    const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    for (final s in items) {
      if (currentDate != s.date) {
        currentDate = s.date;
        rows.add(Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(
            '${s.date.month}/${s.date.day}(${weekdays[s.date.weekday - 1]})',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ));
      }
      rows.add(_buildRow(s));
    }
    return ListView(children: rows);
  }

  Widget _buildRow(MemberSchedule s) {
    final time = s.hasTime
        ? '${s.hour.toString().padLeft(2, '0')}:${s.minute.toString().padLeft(2, '0')}'
        : '終日';
    final hidden = s.isPrivate && !s.mine;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(width: 4, height: 32, decoration: BoxDecoration(color: Color(s.colorValue), borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          SizedBox(width: 44, child: Text(time, style: const TextStyle(fontSize: 12, color: Colors.grey))),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (s.isPrivate) const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(Icons.lock_outline, size: 14, color: Colors.grey),
                    ),
                    Flexible(
                      child: Text(
                        s.title,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontStyle: hidden ? FontStyle.italic : null,
                          decoration: s.completed ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                  ],
                ),
                if (s.description.isNotEmpty)
                  Text(s.description, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Chip(
            label: Text(s.mine ? '自分' : s.ownerName, style: const TextStyle(fontSize: 11)),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
